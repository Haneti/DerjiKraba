require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const TelegramBot = require('node-telegram-bot-api');

// Proxy configuration for Telegram Bot
const BOT_PROXY = process.env.BOT_PROXY || null; // Format: http://username:password@host:port or http://host:port
let botOptions = {};

if (BOT_PROXY) {
  try {
    // Use tunnel option which is built into node-telegram-bot-api
    const HttpsProxyAgent = require('https-proxy-agent');
    const agent = new HttpsProxyAgent(BOT_PROXY);
    
    botOptions = {
      polling: true,
      baseApiUrl: 'https://api.telegram.org',
      request: {
        agent: agent,
        httpsAgent: agent,
        simple: false,
        resolveWithFullResponse: true
      }
    };
    console.log('🔐 Using proxy for Telegram Bot:', BOT_PROXY);
  } catch (e) {
    console.error('❌ Failed to configure proxy:', e.message);
    console.log('⚠️ Running without proxy');
    botOptions = { polling: true };
  }
} else {
  botOptions = { polling: true };
  console.log('ℹ️ No proxy configured for Telegram Bot');
}

const bot = new TelegramBot(process.env.TG_BOT_TOKEN, botOptions);
const multer = require('multer');
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');


const app = express();
app.use(cors());
app.use(express.json());
app.use('/images', express.static('C:/DerjiKraba-Api/public/images')); // Статика для изображений

// Настройка multer для загрузки файлов
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = 'C:/DerjiKraba-Api/public/images';
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const uniqueName = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueName + path.extname(file.originalname));
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 } // Лимит 5MB
});

// Глобальный лог каждого запроса
app.use((req, _res, next) => {
  console.log(new Date().toISOString(), req.method, req.url, Object.keys(req.body || {}).length ? req.body : '');
  next();
});

const pool = mysql.createPool((process.env.DB_URL || 'mysql://krab:S3cure!Pass@127.0.0.1:3306/derjikrab') + '?charset=utf8mb4');
const db = pool;
// Health
app.get('/health', (_req, res) => res.json({ ok: true }));

// Загрузка изображения товара
app.post('/products/:productId/image', upload.single('image'), async (req, res) => {
  try {
    const { productId } = req.params;
    
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }
    
    // Проверяем существование товара
    const [products] = await pool.query('SELECT id FROM products WHERE id = ?', [productId]);
    if (products.length === 0) {
      if (fs.existsSync(req.file.path)) {
        fs.unlinkSync(req.file.path); // Удаляем файл
      }
      return res.status(404).json({ error: 'Product not found' });
    }
    
    // Вычисляем SHA256 хэш файла
    const fileData = fs.readFileSync(req.file.path);
    const hash = crypto.createHash('sha256').update(fileData).digest('hex');
    
    // Формируем URL (используем статический путь /images)
    const imageUrl = `https://derji-kraba.ru/api/images/${path.basename(req.file.path)}`;
    
    // Обновляем запись в БД
    await pool.query(
      'UPDATE products SET image_url = ?, image_hash = ? WHERE id = ?',
      [imageUrl, hash, productId]
    );
    
    res.json({ 
      ok: true, 
      imageUrl: imageUrl,
      imageHash: hash 
    });
  } catch (e) {
    console.error('POST /products/:productId/image error', e);
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    res.status(500).json({ error: 'Upload failed', detail: String(e) });
  }
});

// Удаление изображения товара
app.delete('/products/:productId/image', async (req, res) => {
  try {
    const { productId } = req.params;
    
    // Получаем текущий URL изображения
    const [products] = await pool.query('SELECT image_url FROM products WHERE id = ?', [productId]);
    if (products.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    
    const product = products[0];
    if (product.image_url) {
      // Извлекаем имя файла из URL
      const fileName = path.basename(product.image_url);
      const filePath = path.join('C:/DerjiKraba-Api/public/images', fileName);
      
      // Удаляем файл если существует
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    }
    
    // Очищаем поля в БД
    await pool.query(
      'UPDATE products SET image_url = NULL, image_hash = NULL WHERE id = ?',
      [productId]
    );
    
    res.json({ ok: true });
  } catch (e) {
    console.error('DELETE /products/:productId/image error', e);
    res.status(500).json({ error: 'Delete failed', detail: String(e) });
  }
});

// Справка: отладочный список пользователей
function mapUser(row) {
  return {
    id: row.id,
    phone: row.phone,
    firstName: row.firstName,
    lastName: row.lastName,
    middleName: row.middleName,
    role: row.role,
    isVerified: row.isVerified === 1 || row.isVerified === true
  };
}

function toMysqlDate(value) {
  if (!value) return null;
  const d = new Date(value);
  if (isNaN(d.getTime())) return null;
  // создаём строку в формате MySQL DATETIME
  return d.getFullYear() + '-' +
         String(d.getMonth()+1).padStart(2,'0') + '-' +
         String(d.getDate()).padStart(2,'0') + ' ' +
         String(d.getHours()).padStart(2,'0') + ':' +
         String(d.getMinutes()).padStart(2,'0') + ':' +
         String(d.getSeconds()).padStart(2,'0');
}

function mapProduct(row) {
  return {
    id: row.id,
    name: row.name,
    category: row.category,
    pricePerKg: row.pricePerKg,
    quantityInStock: row.quantityInStock,
    deliveryDate: row.deliveryDate,
    expiryDate: row.expiryDate,
    description: row.description,
    isAvailable: row.isAvailable === 1 || row.isAvailable === true,
    unitType: row.unitType || 'kg',
    imageURL: row.imageURL || row.image_url || null,
    imageHash: row.imageHash || row.image_hash || null
  };
}

app.get('/users', async (req, res) => {
  const search = String(req.query.search || '').trim();
  const phoneSearch = search.replace(/\D/g, '');
  const criteria = String(req.query.criteria || 'all');
  const values = [];
  let where = '';

  if (search) {
    if (criteria === 'phone') {
      if (phoneSearch) {
        where = 'WHERE phone LIKE ?';
        values.push(`%${phoneSearch}%`);
      } else {
        where = 'WHERE 1 = 0';
      }
    } else if (criteria === 'fullName') {
      where = `WHERE LOWER(CONCAT_WS(' ', last_name, first_name, middle_name)) LIKE LOWER(?)`;
      values.push(`%${search}%`);
    } else if (phoneSearch) {
      where = `WHERE LOWER(CONCAT_WS(' ', last_name, first_name, middle_name)) LIKE LOWER(?) OR phone LIKE ?`;
      values.push(`%${search}%`, `%${phoneSearch}%`);
    } else {
      where = `WHERE LOWER(CONCAT_WS(' ', last_name, first_name, middle_name)) LIKE LOWER(?)`;
      values.push(`%${search}%`);
    }
  }

  const [rows] = await pool.query(`
    SELECT id, phone, first_name AS firstName, last_name AS lastName, middle_name AS middleName,
           role, is_verified AS isVerified, created_at
    FROM users ${where}
    ORDER BY created_at DESC LIMIT 50
  `, values);
  res.json(rows.map(mapUser));
});

// AUTH: регистрация
app.post('/auth/register', async (req, res) => {
  const { phone, first_name, last_name, middle_name } = req.body || {};
  if (!phone || !first_name || !last_name) {
    return res.status(400).json({ error: 'phone, first_name, last_name are required' });
  }
  const conn = await pool.getConnection();
  try {
    const [[{ cnt }]] = await conn.query(`SELECT COUNT(*) AS cnt FROM users WHERE phone = ?`, [phone]);
    if (cnt > 0) {
      await conn.query(`
        UPDATE users
        SET first_name = ?, last_name = ?, middle_name = ?, role = ?
        WHERE phone = ?
      `, [first_name, last_name, middle_name ?? null, role || 'employee', phone]);
      const [rows] = await conn.query(`
        SELECT id, phone, first_name AS firstName, last_name AS lastName, middle_name AS middleName,
               role, is_verified AS isVerified
        FROM users WHERE phone = ? LIMIT 1
      `, [phone]);
      return res.json(mapUser(rows[0]));
    }
    const [[{ uuid: id }]] = await conn.query(`SELECT UUID() AS uuid`);
    await conn.query(`
      INSERT INTO users (id, phone, first_name, last_name, middle_name, role, is_verified)
      VALUES (?, ?, ?, ?, ?, 'client', 1)
    `, [id, phone, first_name, last_name, middle_name ?? null]);

    const [rows] = await conn.query(`
      SELECT id, phone, first_name AS firstName, last_name AS lastName, middle_name AS middleName,
             role, is_verified AS isVerified
      FROM users WHERE id = ? LIMIT 1
    `, [id]);
    res.json(mapUser(rows[0]));
  } catch (e) {
    res.status(500).json({ error: 'DB error', detail: String(e) });
  } finally {
    conn.release();
  }
});

// AUTH: логин по телефону
app.post('/auth/login', async (req, res) => {
  const { phone } = req.body || {};
  if (!phone) return res.status(400).json({ error: 'phone is required' });
  const [rows] = await pool.query(`
    SELECT id, phone, first_name AS firstName, last_name AS lastName, middle_name AS middleName,
           role, is_verified AS isVerified
    FROM users WHERE phone = ? LIMIT 1
  `, [phone]);
  if (rows.length === 0) return res.status(404).json({ error: 'not found' });
  res.json(mapUser(rows[0]));
});

app.post('/api/orders', async (req, res) => {
  const { 
    user_id, 
    delivery_type, 
    delivery_address, 
    delivery_details, // JSON string
    notes, 
    items 
  } = req.body || {};
  
  if (!user_id || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: 'Invalid payload: user_id and items required' });
  }
  
  // Парсим JSON с деталями
  let details = {};
  try {
    if (delivery_details) {
      details = JSON.parse(delivery_details);
    }
  } catch (e) {
    console.warn('Failed to parse delivery_details:', e);
  }
  
  const total = items.reduce((s, i) => s + Number(i.quantity || 0) * Number(i.price_per_kg || 0), 0);
  const conn = await pool.getConnection();
  
  try {
    await conn.beginTransaction();
    const [[{ uuid: orderId }]] = await conn.query(`SELECT UUID() AS uuid`);
    
    await conn.query(`
      INSERT INTO orders (
        id, user_id, order_date, status, 
        delivery_type, delivery_address, delivery_details,
        house_type, entrance, floor, apartment, intercom, intercom_broken,
        latitude, longitude,
        total_amount, notes
      )
      VALUES (?, ?, NOW(), 'pending', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      orderId,
      user_id,
      delivery_type || 'delivery',
      delivery_address ?? null,
      delivery_details ?? null,
      details.house_type || 'apartment',
      details.entrance || null,
      details.floor || null,
      details.apartment || null,
      details.intercom || null,
      details.intercom_broken || false,
      details.latitude || null,
      details.longitude || null,
      total,
      notes ?? null
    ]);
    
    for (const it of items) {
      const [[{ uuid: itemId }]] = await conn.query(`SELECT UUID() AS uuid`);
      await conn.query(`
        INSERT INTO order_items (id, order_id, product_id, quantity, price_per_kg)
        VALUES (?, ?, ?, ?, ?)
      `, [itemId, orderId, it.product_id ?? null, it.quantity, it.price_per_kg]);
    }
    
    await conn.commit();
    res.json({ ok: true, order_id: orderId });
  } catch (e) {
    await conn.rollback();
    console.error('POST /api/orders error:', e);
    res.status(500).json({ error: 'DB error', detail: String(e) });
  } finally {
    conn.release();
  }
});

// Каталог
app.get('/products', async (_req, res) => {
  const [rows] = await pool.query(`
    SELECT id,
           name,
           category,
           price_per_kg AS pricePerKg,
           quantity_in_stock AS quantityInStock,
           delivery_date AS deliveryDate,
           expiry_date AS expiryDate,
           description,
           is_available AS isAvailable,
           unit_type AS unitType,
           image_url AS imageURL,
           image_hash AS imageHash
    FROM products
    ORDER BY name
  `);
  res.json(rows.map(mapProduct));
});
// Создание нового товара
app.post('/products', async (req, res) => {
  const {
    name,
    category,
    price_per_kg,
    quantity_in_stock,
    delivery_date,
    expiry_date,
    description,
    is_available,
    unit_type,
    image_url,
    image_hash
  } = req.body || {};

  if (!name || !category || price_per_kg == null || quantity_in_stock == null) {
    return res.status(400).json({ error: 'name, category, price_per_kg, quantity_in_stock are required' });
  }

  const isAvailableValue = (is_available === undefined || is_available === null)
    ? 1
    : (is_available === true || is_available === 1 || is_available === '1' ? 1 : 0);

  const unitTypeValue = unit_type === 'piece' ? 'piece' : 'kg';
  const delivery = toMysqlDate(delivery_date) ?? toMysqlDate(new Date());
  const expiry   = toMysqlDate(expiry_date) ?? toMysqlDate(new Date());

  const conn = await pool.getConnection();
  try {
    const [[{ uuid: id }]] = await conn.query('SELECT UUID() AS uuid');

    await conn.query(
      `INSERT INTO products 
      (id, name, category, price_per_kg, quantity_in_stock, delivery_date, expiry_date, description, is_available, unit_type, image_url, image_hash)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id, name, category, price_per_kg, quantity_in_stock,
        delivery, expiry, description ?? null, isAvailableValue, unitTypeValue, image_url ?? null, image_hash ?? null
      ]
    );

    const [rows] = await conn.query(
      `SELECT id, name, category,
              price_per_kg AS pricePerKg,
              quantity_in_stock AS quantityInStock,
              delivery_date AS deliveryDate,
              expiry_date AS expiryDate,
              description,
              is_available AS isAvailable,
              unit_type AS unitType,
              image_url AS imageURL,
              image_hash AS imageHash
       FROM products
       WHERE id = ?
       LIMIT 1`,
      [id]
    );

    res.json(mapProduct(rows[0]));
  } catch (e) {
    console.error('POST /products error', e);
    res.status(500).json({ error: 'DB error', detail: String(e) });
  } finally {
    conn.release();
  }
});

app.patch('/users/:id/role', async (req, res) => {
  const { id } = req.params;
  const { role } = req.body;

  if (!role) {
    return res.status(400).json({ error: 'role is required' });
  }
  if (!['client', 'employee', 'owner'].includes(role)) {
    return res.status(400).json({ error: 'invalid role' });
  }

  try {
    if (role !== 'owner') {
      const [users] = await pool.query('SELECT role FROM users WHERE id = ? LIMIT 1', [id]);
      if (!users.length) {
        return res.status(404).json({ error: 'User not found' });
      }
      if (users[0].role === 'owner') {
        const [[{ cnt }]] = await pool.query(`SELECT COUNT(*) AS cnt FROM users WHERE role = 'owner'`);
        if (cnt <= 1) {
          return res.status(400).json({ error: 'Cannot remove last owner' });
        }
      }
    }

    const [result] = await pool.query(
      'UPDATE users SET role = ? WHERE id = ?',
      [role, id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const [rows] = await pool.query(
      `SELECT id, phone, first_name AS firstName, last_name AS lastName, middle_name AS middleName,
              role, is_verified AS isVerified
       FROM users WHERE id = ? LIMIT 1`,
      [id]
    );

    res.json(mapUser(rows[0]));
  } catch (e) {
    console.error('PATCH /users/:id/role error', e);
    res.status(500).json({ error: 'DB error', detail: String(e) });
  }
});

app.delete('/users/:id', async (req, res) => {
  const { id } = req.params;
  const conn = await pool.getConnection();

  try {
    await conn.beginTransaction();

    const [users] = await conn.query('SELECT phone, role FROM users WHERE id = ? LIMIT 1', [id]);
    if (!users.length) {
      await conn.rollback();
      return res.status(404).json({ error: 'User not found' });
    }

    const user = users[0];
    if (user.role === 'owner') {
      const [[{ cnt }]] = await conn.query(`SELECT COUNT(*) AS cnt FROM users WHERE role = 'owner'`);
      if (cnt <= 1) {
        await conn.rollback();
        return res.status(400).json({ error: 'Cannot delete last owner' });
      }
    }

    await conn.query('UPDATE orders SET user_id = NULL WHERE user_id = ?', [id]);
    await conn.query('DELETE FROM support_messages WHERE client_phone = ? OR sender_phone = ?', [user.phone, user.phone]);
    await conn.query('DELETE FROM support_conversations WHERE client_phone = ?', [user.phone]);
    await conn.query('DELETE FROM users WHERE id = ?', [id]);

    await conn.commit();
    res.json({ ok: true });
  } catch (e) {
    await conn.rollback();
    console.error('DELETE /users/:id error', e);
    res.status(500).json({ error: 'DB error', detail: String(e) });
  } finally {
    conn.release();
  }
});

app.patch('/products/:id', async (req, res) => {
  const { id } = req.params;
  const data = req.body || {};
  
  // Динамически строим UPDATE только для переданных полей
  const updates = [];
  const values = [];
  
  if (data.name !== undefined) {
    updates.push('name = ?');
    values.push(data.name);
  }
  if (data.category !== undefined) {
    updates.push('category = ?');
    values.push(data.category);
  }
  if (data.price_per_kg !== undefined) {
    updates.push('price_per_kg = ?');
    values.push(data.price_per_kg);
  }
  if (data.quantity_in_stock !== undefined) {
    updates.push('quantity_in_stock = ?');
    values.push(data.quantity_in_stock);
  }
  if (data.delivery_date !== undefined) {
    updates.push('delivery_date = ?');
    values.push(toMysqlDate(data.delivery_date));
  }
  if (data.expiry_date !== undefined) {
    updates.push('expiry_date = ?');
    values.push(toMysqlDate(data.expiry_date));
  }
  if (data.description !== undefined) {
    updates.push('description = ?');
    values.push(data.description);
  }
  if (data.is_available !== undefined) {
    const isAvailableValue = (data.is_available === true || data.is_available === 1 || data.is_available === '1') ? 1 : 0;
    updates.push('is_available = ?');
    values.push(isAvailableValue);
  }
  if (data.unit_type !== undefined) {
    const unitTypeValue = data.unit_type === 'piece' ? 'piece' : 'kg';
    updates.push('unit_type = ?');
    values.push(unitTypeValue);
  }
  if (data.image_url !== undefined) {
    updates.push('image_url = ?');
    values.push(data.image_url);
  }
  if (data.image_hash !== undefined) {
    updates.push('image_hash = ?');
    values.push(data.image_hash);
  }
  
  if (updates.length === 0) {
    return res.status(400).json({ error: 'No fields to update' });
  }
  
  values.push(id);
  
  try {
    const [result] = await pool.query(
      `UPDATE products SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    // Если товар не найден, возвращаем ошибку
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }

    const [rows] = await pool.query(
      `SELECT id, name, category,
              price_per_kg AS pricePerKg,
              quantity_in_stock AS quantityInStock,
              delivery_date AS deliveryDate,
              expiry_date AS expiryDate,
              description,
              is_available AS isAvailable,
              unit_type AS unitType,
              image_url AS imageURL,
              image_hash AS imageHash
       FROM products
       WHERE id = ?`,
      [id]
    );

    res.json(mapProduct(rows[0]));
  } catch (e) {
    console.error('PATCH /products error', e);
    res.status(500).json({ error: 'DB error', detail: String(e) });
  }
});


// Удаление товара из каталога
app.delete('/products/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query('DELETE FROM products WHERE id = ?', [id]);
    res.json({ ok: true });
  } catch (e) {
    console.error('DELETE /products error', e);
    res.status(500).json({ error: 'DB error', detail: String(e) });
  }
});

// Заказ (устаревший endpoint - используйте /api/orders для новых полей)
app.post('/orders', async (req, res) => {
  const { 
    user_id, 
    delivery_type, 
    delivery_address, 
    delivery_details, // JSON string с расширенной информацией
    notes, 
    items 
  } = req.body || {};
  
  if (!user_id || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: 'Invalid payload' });
  }
  
  const total = items.reduce((s, i) => s + i.quantity * i.price_per_kg, 0);

  // Парсим JSON с деталями (если есть)
  let details = {};
  try {
    if (delivery_details) {
      details = JSON.parse(delivery_details);
    }
  } catch (e) {
    console.warn('Failed to parse delivery_details:', e);
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [[{ uuid: orderId }]] = await conn.query(`SELECT UUID() AS uuid`);
    await conn.query(`
      INSERT INTO orders (
        id, user_id, order_date, status, 
        delivery_type, delivery_address, delivery_details,
        house_type, entrance, floor, apartment, intercom, intercom_broken,
        latitude, longitude,
        total_amount, notes
      )
      VALUES (?, ?, NOW(), 'pending', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      orderId, user_id, 
      delivery_type, 
      delivery_address ?? null, 
      delivery_details ?? null,
      details.house_type || 'apartment',
      details.entrance || null,
      details.floor || null,
      details.apartment || null,
      details.intercom || null,
      details.intercom_broken || false,
      details.latitude || null,
      details.longitude || null,
      total, 
      notes ?? null
    ]);

    for (const it of items) {
      const [[{ uuid: itemId }]] = await conn.query(`SELECT UUID() AS uuid`);
      await conn.query(`
        INSERT INTO order_items (id, order_id, product_id, quantity, price_per_kg)
        VALUES (?, ?, ?, ?, ?)
      `, [itemId, orderId, it.product_id ?? null, it.quantity, it.price_per_kg]);
    }

    await conn.commit();
    res.json({ ok: true, order_id: orderId });
  } catch (e) {
    await conn.rollback();
    res.status(500).json({ error: 'DB error', detail: String(e) });
  } finally {
    conn.release();
  }
});

app.post('/staff/create', async (req, res) => {
  const { phone, first_name, last_name, middle_name, role } = req.body || {};
  if (!phone || !first_name || !last_name) {
    return res.status(400).json({ error: 'phone, first_name, last_name are required' });
  }
  const targetRole = ['employee', 'owner'].includes(role) ? role : 'employee';
  const conn = await pool.getConnection();
  try {
    const [[{ cnt }]] = await conn.query(`SELECT COUNT(*) AS cnt FROM users WHERE phone = ?`, [phone]);
    if (cnt > 0) {
      await conn.query(`
        UPDATE users
        SET first_name = ?, last_name = ?, middle_name = ?, role = ?
        WHERE phone = ?
      `, [first_name, last_name, middle_name ?? null, targetRole, phone]);
      const [rows] = await conn.query(`
        SELECT id, phone, first_name AS firstName, last_name AS lastName, middle_name AS middleName,
               role, is_verified AS isVerified
        FROM users WHERE phone = ? LIMIT 1
      `, [phone]);
      return res.json(mapUser(rows[0]));
    }
    const [[{ uuid: id }]] = await conn.query(`SELECT UUID() AS uuid`);
    await conn.query(`
      INSERT INTO users (id, phone, first_name, last_name, middle_name, role, is_verified)
      VALUES (?, ?, ?, ?, ?, ?, 1)
    `, [id, phone, first_name, last_name, middle_name ?? null, targetRole]);
    const [rows] = await conn.query(`
      SELECT id, phone, first_name AS firstName, last_name AS lastName, middle_name AS middleName,
             role, is_verified AS isVerified
      FROM users WHERE id = ? LIMIT 1
    `, [id]);
    res.json(mapUser(rows[0]));
  } catch (e) {
    res.status(500).json({ error: 'DB error', detail: String(e) });
  } finally {
    conn.release();
  }
});

// GET /orders — все заказы (для сотрудников/владельца)
app.get('/orders', async (_req, res) => {
  // Основные поля заказа + данные пользователя (ФИО, телефон)
  const [orders] = await pool.query(`
    SELECT
      o.id,
      o.user_id AS userId,
      o.order_date AS orderDate,
      o.status,
      o.delivery_type AS deliveryType,
      o.delivery_address AS deliveryAddress,
      o.delivery_details AS deliveryDetails,
      o.house_type AS houseType,
      o.entrance,
      o.floor,
      o.apartment,
      o.intercom,
      o.intercom_broken AS intercomBroken,
      o.latitude,
      o.longitude,
      o.total_amount AS totalAmount,
      o.notes,
      u.first_name AS firstName,
      u.last_name AS lastName,
      u.middle_name AS middleName,
      u.phone AS phone
    FROM orders o
    LEFT JOIN users u ON u.id = o.user_id
    ORDER BY o.order_date DESC
  `);

  // Позиции заказа и имена товаров
  const [items] = await pool.query(`
    SELECT oi.id, oi.order_id AS orderId, oi.product_id AS productId, oi.quantity, oi.price_per_kg AS pricePerKg,
           p.name AS productName
    FROM order_items oi
    LEFT JOIN products p ON p.id = oi.product_id
  `);
  const byOrder = new Map();
  for (const it of items) {
    if (!byOrder.has(it.orderId)) byOrder.set(it.orderId, []);
    byOrder.get(it.orderId).push({
      id: it.id,
      productId: it.productId,
      quantity: it.quantity,
      pricePerKg: it.pricePerKg,
      productName: it.productName
    });
  }

  const out = orders.map(o => {
    let customer = null;
    if (o.phone) {
      const parts = [];
      if (o.lastName) parts.push(o.lastName);
      if (o.firstName) parts.push(o.firstName);
      if (o.middleName) parts.push(o.middleName);
      customer = {
        fullName: parts.join(' ') || o.phone,
        phone: o.phone,
        // Для удобства в приложении используем адрес доставки заказа
        address: o.deliveryAddress ?? null
      };
    }
    return {
      id: o.id,
      userId: o.userId,
      orderDate: o.orderDate,
      status: o.status,
      deliveryType: o.deliveryType,
      deliveryAddress: o.deliveryAddress,
      deliveryDetails: o.deliveryDetails,
      houseType: o.houseType,
      entrance: o.entrance,
      floor: o.floor,
      apartment: o.apartment,
      intercom: o.intercom,
      intercomBroken: o.intercomBroken,
      latitude: o.latitude,
      longitude: o.longitude,
      totalAmount: o.totalAmount,
      notes: o.notes,
      items: byOrder.get(o.id) || [],
      customer
    };
  });

  res.json(out);
});

// GET /orders/user/:userId — заказы конкретного пользователя
app.get('/orders/user/:userId', async (req, res) => {
  const { userId } = req.params;

  const [orders] = await pool.query(`
    SELECT
      o.id,
      o.user_id AS userId,
      o.order_date AS orderDate,
      o.status,
      o.delivery_type AS deliveryType,
      o.delivery_address AS deliveryAddress,
      o.delivery_details AS deliveryDetails,
      o.house_type AS houseType,
      o.entrance,
      o.floor,
      o.apartment,
      o.intercom,
      o.intercom_broken AS intercomBroken,
      o.latitude,
      o.longitude,
      o.total_amount AS totalAmount,
      o.notes,
      u.first_name AS firstName,
      u.last_name AS lastName,
      u.middle_name AS middleName,
      u.phone AS phone
    FROM orders o
    LEFT JOIN users u ON u.id = o.user_id
    WHERE o.user_id = ?
    ORDER BY o.order_date DESC
  `, [userId]);

  const [items] = await pool.query(`
    SELECT oi.id, oi.order_id AS orderId, oi.product_id AS productId, oi.quantity, oi.price_per_kg AS pricePerKg,
           p.name AS productName
    FROM order_items oi
    LEFT JOIN products p ON p.id = oi.product_id
    WHERE oi.order_id IN (${orders.map(_ => '?').join(',') || "''"})
  `, orders.map(o => o.id));

  const byOrder = new Map();
  for (const it of items) {
    if (!byOrder.has(it.orderId)) byOrder.set(it.orderId, []);
    byOrder.get(it.orderId).push({
      id: it.id,
      productId: it.productId,
      quantity: it.quantity,
      pricePerKg: it.pricePerKg,
      productName: it.productName
    });
  }

  const out = orders.map(o => {
    let customer = null;
    if (o.phone) {
      const parts = [];
      if (o.lastName) parts.push(o.lastName);
      if (o.firstName) parts.push(o.firstName);
      if (o.middleName) parts.push(o.middleName);
      customer = {
        fullName: parts.join(' ') || o.phone,
        phone: o.phone,
        address: o.deliveryAddress ?? null
      };
    }
    return {
      id: o.id,
      userId: o.userId,
      orderDate: o.orderDate,
      status: o.status,
      deliveryType: o.deliveryType,
      deliveryAddress: o.deliveryAddress,
      deliveryDetails: o.deliveryDetails,
      houseType: o.houseType,
      entrance: o.entrance,
      floor: o.floor,
      apartment: o.apartment,
      intercom: o.intercom,
      intercomBroken: o.intercomBroken,
      latitude: o.latitude,
      longitude: o.longitude,
      totalAmount: o.totalAmount,
      notes: o.notes,
      items: byOrder.get(o.id) || [],
      customer
    };
  });

  res.json(out);
});

// PATCH /orders/:id — обновление статуса
app.patch('/orders/:id', async (req, res) => {
  const { id } = req.params;
  const { status } = req.body || {};
  const allowed = new Set(['pending','processing','ready','delivering','completed','cancelled']);
  if (!allowed.has(status)) return res.status(400).json({ error: 'invalid status' });
  await pool.query(`UPDATE orders SET status = ? WHERE id = ?`, [status, id]);
  res.json({ ok: true });
});
// === Support chat (клиент ↔ сотрудники) ===
function normalizePhone(value) {
  if (!value) return null;
  const digits = String(value).replace(/\D/g, '');
  if (!digits) return null;
  let d = digits;
  if (d[0] === '8') d = '7' + d.slice(1);
  if (d[0] !== '7') d = '7' + d;
  return d;
}

function mapSupportConversation(row) {
  const parts = [];
  if (row.lastName) parts.push(row.lastName);
  if (row.firstName) parts.push(row.firstName);
  if (row.middleName) parts.push(row.middleName);
  const clientName = parts.join(' ').trim();
  return {
    clientPhone: row.clientPhone,
    clientName: clientName || row.clientPhone,
    lastMessageAt: row.lastMessageAt ?? null,
    lastMessageText: row.lastMessageText ?? null,
    lastSenderRole: row.lastSenderRole ?? null,
    needsStaffReply: row.needsStaffReply === 1 || row.needsStaffReply === true
  };
}

function mapSupportMessage(row) {
  return {
    id: row.id,
    clientPhone: row.clientPhone,
    senderPhone: row.senderPhone,
    senderRole: row.senderRole,
    text: row.text,
    createdAt: row.createdAt
  };
}

// Список диалогов (для сотрудников)
app.get('/support/conversations', async (_req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT
        sc.client_phone AS clientPhone,
        sc.last_message_at AS lastMessageAt,
        sc.last_message_text AS lastMessageText,
        sc.last_sender_role AS lastSenderRole,
        sc.needs_staff_reply AS needsStaffReply,
        u.first_name AS firstName,
        u.last_name AS lastName,
        u.middle_name AS middleName
      FROM support_conversations sc
      LEFT JOIN users u ON u.phone = sc.client_phone
      ORDER BY sc.last_message_at DESC, sc.updated_at DESC
    `);
    res.json(rows.map(mapSupportConversation));
  } catch (e) {
    console.error('GET /support/conversations error', e);
    res.status(500).json({ error: 'DB error', detail: String(e) });
  }
});

// Метаданные одного диалога (для клиента — чтобы понять, есть ли ответ)
app.get('/support/conversations/:phone', async (req, res) => {
  const clientPhone = normalizePhone(req.params.phone) ?? req.params.phone;
  try {
    const [rows] = await pool.query(`
      SELECT
        sc.client_phone AS clientPhone,
        sc.last_message_at AS lastMessageAt,
        sc.last_message_text AS lastMessageText,
        sc.last_sender_role AS lastSenderRole,
        sc.needs_staff_reply AS needsStaffReply,
        u.first_name AS firstName,
        u.last_name AS lastName,
        u.middle_name AS middleName
      FROM support_conversations sc
      LEFT JOIN users u ON u.phone = sc.client_phone
      WHERE sc.client_phone = ?
      LIMIT 1
    `, [clientPhone]);

    if (!rows.length) return res.status(404).json({ error: 'not found' });
    res.json(mapSupportConversation(rows[0]));
  } catch (e) {
    console.error('GET /support/conversations/:phone error', e);
    res.status(500).json({ error: 'DB error', detail: String(e) });
  }
});

// История сообщений диалога
app.get('/support/conversations/:phone/messages', async (req, res) => {
  const clientPhone = normalizePhone(req.params.phone) ?? req.params.phone;
  try {
    const [rows] = await pool.query(`
      SELECT
        id,
        client_phone AS clientPhone,
        sender_phone AS senderPhone,
        sender_role AS senderRole,
        text,
        created_at AS createdAt
      FROM support_messages
      WHERE client_phone = ?
      ORDER BY created_at ASC
    `, [clientPhone]);
    res.json(rows.map(mapSupportMessage));
  } catch (e) {
    console.error('GET /support/conversations/:phone/messages error', e);
    res.status(500).json({ error: 'DB error', detail: String(e) });
  }
});

app.patch('/support/conversations/:phone/read', async (req, res) => {
  const clientPhone = normalizePhone(req.params.phone) ?? req.params.phone;
  try {
    await pool.query(
      `UPDATE support_conversations
       SET needs_staff_reply = 0
       WHERE client_phone = ?`,
      [clientPhone]
    );
    res.json({ ok: true });
  } catch (e) {
    console.error('PATCH /support/conversations/:phone/read error', e);
    res.status(500).json({ error: 'DB error', detail: String(e) });
  }
});

// Отправка сообщения
app.post('/support/conversations/:phone/messages', async (req, res) => {
  const clientPhone = normalizePhone(req.params.phone) ?? req.params.phone;
  const senderPhone = normalizePhone(req.body?.senderPhone) ?? req.body?.senderPhone;
  const text = String(req.body?.text ?? '').trim();

  if (!clientPhone || !senderPhone || !text) {
    return res.status(400).json({ error: 'clientPhone, senderPhone, text are required' });
  }
  if (text.length > 5000) {
    return res.status(400).json({ error: 'text is too long' });
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // Клиент должен существовать и быть client
    const [clientRows] = await conn.query(
      `SELECT phone, role FROM users WHERE phone = ? LIMIT 1`,
      [clientPhone]
    );
    if (!clientRows.length) {
      await conn.rollback();
      return res.status(404).json({ error: 'client not found' });
    }
    if (clientRows[0].role !== 'client') {
      await conn.rollback();
      return res.status(400).json({ error: 'conversation phone must belong to client' });
    }

    // Отправитель должен существовать; роль берём из БД
    const [senderRows] = await conn.query(
      `SELECT phone, role FROM users WHERE phone = ? LIMIT 1`,
      [senderPhone]
    );
    if (!senderRows.length) {
      await conn.rollback();
      return res.status(404).json({ error: 'sender not found' });
    }

    const senderRole = senderRows[0].role;

    // Клиент может писать только в свой диалог
    if (senderRole === 'client' && senderPhone !== clientPhone) {
      await conn.rollback();
      return res.status(403).json({ error: 'client can only write to own conversation' });
    }

    // Создаём диалог, если его ещё нет
    await conn.query(
      `INSERT INTO support_conversations (client_phone) VALUES (?)
       ON DUPLICATE KEY UPDATE client_phone = client_phone`,
      [clientPhone]
    );

    // Добавляем сообщение
    const [[{ uuid: messageId }]] = await conn.query(`SELECT UUID() AS uuid`);
    await conn.query(
      `INSERT INTO support_messages (id, client_phone, sender_phone, sender_role, text, created_at)
       VALUES (?, ?, ?, ?, ?, NOW())`,
      [messageId, clientPhone, senderPhone, senderRole, text]
    );

    // Обновляем агрегаты диалога
    const needsStaffReply = senderRole === 'client' ? 1 : 0;
    await conn.query(
      `UPDATE support_conversations
       SET last_message_at = NOW(),
           last_message_text = ?,
           last_sender_role = ?,
           needs_staff_reply = ?
       WHERE client_phone = ?`,
      [text, senderRole, needsStaffReply, clientPhone]
    );

    await conn.commit();
    res.json({ ok: true, message_id: messageId });
  } catch (e) {
    try { await conn.rollback(); } catch (_) {}
    console.error('POST /support/conversations/:phone/messages error', e);
    res.status(500).json({ error: 'DB error', detail: String(e) });
  } finally {
    conn.release();
  }
});

app.post('/support/conversations/:phone/images', upload.single('image'), async (req, res) => {
  const clientPhone = normalizePhone(req.params.phone) ?? req.params.phone;
  const senderPhone = normalizePhone(req.body?.senderPhone) ?? req.body?.senderPhone;

  if (!clientPhone || !senderPhone || !req.file) {
    if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    return res.status(400).json({ error: 'clientPhone, senderPhone, image are required' });
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    const [clientRows] = await conn.query(
      `SELECT phone, role FROM users WHERE phone = ? LIMIT 1`,
      [clientPhone]
    );
    if (!clientRows.length || clientRows[0].role !== 'client') {
      await conn.rollback();
      if (fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(400).json({ error: 'conversation phone must belong to client' });
    }

    const [senderRows] = await conn.query(
      `SELECT phone, role FROM users WHERE phone = ? LIMIT 1`,
      [senderPhone]
    );
    if (!senderRows.length) {
      await conn.rollback();
      if (fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(404).json({ error: 'sender not found' });
    }

    const senderRole = senderRows[0].role;
    if (senderRole === 'client' && senderPhone !== clientPhone) {
      await conn.rollback();
      if (fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(403).json({ error: 'client can only write to own conversation' });
    }

    const ext = path.extname(req.file.originalname).toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.heic', '.webp'].includes(ext)) {
      await conn.rollback();
      if (fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(400).json({ error: 'unsupported image format' });
    }

    const imageUrl = `https://derji-kraba.ru/api/images/${path.basename(req.file.path)}`;
    const text = `[[image]]${imageUrl}`;

    await conn.query(
      `INSERT INTO support_conversations (client_phone) VALUES (?)
       ON DUPLICATE KEY UPDATE client_phone = client_phone`,
      [clientPhone]
    );

    const [[{ uuid: messageId }]] = await conn.query(`SELECT UUID() AS uuid`);
    await conn.query(
      `INSERT INTO support_messages (id, client_phone, sender_phone, sender_role, text, created_at)
       VALUES (?, ?, ?, ?, ?, NOW())`,
      [messageId, clientPhone, senderPhone, senderRole, text]
    );

    const needsStaffReply = senderRole === 'client' ? 1 : 0;
    await conn.query(
      `UPDATE support_conversations
       SET last_message_at = NOW(),
           last_message_text = ?,
           last_sender_role = ?,
           needs_staff_reply = ?
       WHERE client_phone = ?`,
      ['Фото', senderRole, needsStaffReply, clientPhone]
    );

    await conn.commit();
    res.json({ ok: true, message_id: messageId, imageUrl });
  } catch (e) {
    try { await conn.rollback(); } catch (_) {}
    if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    console.error('POST /support/conversations/:phone/images error', e);
    res.status(500).json({ error: 'Upload failed', detail: String(e) });
  } finally {
    conn.release();
  }
});


// Нормализация телефона: +7, 8 → 7
function normalizePhone(value) {
  if (!value) return null;
  const digits = String(value).replace(/\D/g, '');
  if (!digits) return null;
  let d = digits;
  // Заменяем 8 на 7 в начале
  if (d[0] === '8') d = '7' + d.slice(1);
  // Если не начинается с 7, добавляем 7
  if (d[0] !== '7') d = '7' + d;
  return d;
}

bot.onText(/\/start (.+)/, async (msg, match) => {
  const chatId = msg.chat.id;
  const phone = match[1];
  
  // Нормализуем телефон перед обновлением
  const normalizedPhone = normalizePhone(phone);
  
  if (!normalizedPhone) {
    bot.sendMessage(chatId, "❌ Неверный формат номера");
    return;
  }

  const [rows] = await pool.query(
    "UPDATE users SET telegram_chat_id = ? WHERE phone = ?",
    [chatId, normalizedPhone]
  );

  bot.sendMessage(chatId, "✅ Telegram успешно привязан к аккаунту!");
});

app.post("/auth/request-code", async (req, res) => {
  const { phone } = req.body;

  const [users] = await pool.query("SELECT * FROM users WHERE phone = ?", [phone]);
  if (users.length === 0) return res.status(404).json({ error: "User not found" });

  const user = users[0];
  if (!user.telegram_chat_id) {
    return res.status(400).json({ error: "Telegram not linked" });
  }

  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const expires = new Date(Date.now() + 5 * 60 * 1000);

  await pool.query(
    "UPDATE users SET login_code = ?, login_code_expires = ? WHERE id = ?",
    [code, expires, user.id]
  );

  await bot.sendMessage(user.telegram_chat_id, `🔐 Ваш код входа: ${code}\nДействителен 5 минут.`);

  res.json({ ok: true });
});

app.post("/auth/verify-code", async (req, res) => {
  const { phone, code } = req.body;

  const [rows] = await pool.query(
    "SELECT * FROM users WHERE phone = ? AND login_code = ? AND login_code_expires > NOW()",
    [phone, code]
  );

  if (rows.length === 0) {
    return res.status(400).json({ error: "Invalid or expired code" });
  }

  const user = rows[0];

  await pool.query(
    "UPDATE users SET login_code = NULL, login_code_expires = NULL WHERE id = ?",
    [user.id]
  );

  res.json(user);
});


const port = process.env.PORT || 3000;
const host = '0.0.0.0'; // слушаем все интерфейсы, не только 127.0.0.1
app.listen(port, host, () => console.log(`API listening on http://${host}:${port}`));
console.log("BOT TOKEN:", process.env.TG_BOT_TOKEN);
