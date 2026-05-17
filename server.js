require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const TelegramBot = require('node-telegram-bot-api');
const jwt = require('jsonwebtoken');

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

// ========== SECURITY CONFIGURATION ==========
const JWT_SECRET = process.env.JWT_SECRET || crypto.randomBytes(32).toString('hex');
const MOBILE_API_KEY = process.env.MOBILE_API_KEY || 'be5e23bdd69baeeb2e7c97948f35faa5fae7b924613e52ece589bc24821e1051'; // Change in production!
const TRUSTED_ORIGINS = [
  'https://derji-kraba.ru',
  'https://www.derji-kraba.ru',
  'http://localhost:3000',
  'http://localhost:8080',
  'capacitor://localhost', // iOS app
  'ionic://localhost'    // iOS app alternative
];

// Rate limiting storage (in-memory, resets on restart)
const requestCounts = new Map();
const RATE_LIMIT_WINDOW = 60 * 1000; // 1 minute
const RATE_LIMIT_MAX = 100; // max 100 requests per minute per IP

// Security middleware
app.use((req, res, next) => {
  // Security headers
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  next();
});

// CORS with origin validation
app.use(cors({
  origin: function(origin, callback) {
    // Allow requests with no origin (mobile apps, curl, etc)
    if (!origin) return callback(null, true);
    if (TRUSTED_ORIGINS.includes(origin)) {
      return callback(null, true);
    }
    // Log suspicious origins
    console.warn(`🚫 Blocked CORS request from untrusted origin: ${origin}`);
    callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key']
}));

app.use(express.json({ limit: '10mb' }));
app.use('/images', express.static('C:/DerjiKraba-Api/public/images'));

// Rate limiting middleware
function rateLimit(req, res, next) {
  const ip = req.ip || req.connection.remoteAddress || 'unknown';
  const now = Date.now();
  
  if (!requestCounts.has(ip)) {
    requestCounts.set(ip, { count: 1, resetTime: now + RATE_LIMIT_WINDOW });
  } else {
    const data = requestCounts.get(ip);
    if (now > data.resetTime) {
      data.count = 1;
      data.resetTime = now + RATE_LIMIT_WINDOW;
    } else {
      data.count++;
      if (data.count > RATE_LIMIT_MAX) {
        console.warn(`🚫 Rate limit exceeded for IP: ${ip}`);
        return res.status(429).json({ error: 'Too many requests, please try again later' });
      }
    }
  }
  next();
}

// Block scrapers/bots for public endpoints
function antiScrape(req, res, next) {
  // Only apply to public GET endpoints
  if (req.method !== 'GET' || req.path !== '/products') {
    return next();
  }
  
  // Check if request has valid Mobile API Key (from iOS app)
  const mobileKey = req.headers['x-mobile-key'];
  if (mobileKey === MOBILE_API_KEY) {
    // Valid mobile app request, allow
    return next();
  }
  
  const userAgent = req.headers['user-agent'] || '';
  const blockedAgents = [
    'curl', 'wget', 'python', 'scrapy', 'httpclient', 'axios', 
    'postman', 'insomnia', 'bot', 'crawler', 'spider', 'headless',
    'puppeteer', 'playwright', 'selenium'
  ];
  
  // Check for suspicious User-Agents
  const isBlocked = blockedAgents.some(agent => 
    userAgent.toLowerCase().includes(agent)
  );
  
  if (isBlocked || userAgent.length === 0) {
    console.warn(`🚫 Blocked scraper: "${userAgent.substring(0, 50)}" from IP: ${req.ip}`);
    return res.status(403).json({ error: 'Access denied' });
  }
  
  // Log suspicious direct API access (no mobile key)
  console.log(`⚠️ API access without mobile key from: ${userAgent.substring(0, 50)} IP: ${req.ip}`);
  
  next();
}

// JWT + Session Key validation middleware
function requireAuth(req, res, next) {
  // Skip for GET requests to public endpoints
  if (req.method === 'GET' && (
    req.path === '/products' || 
    req.path.startsWith('/images/') ||
    req.path === '/'
  )) {
    return next();
  }
  
  // Skip auth endpoints (they handle their own auth)
  if (req.path.startsWith('/auth/')) {
    return next();
  }
  
  // Check JWT token
  const authHeader = req.headers['authorization'];
  const sessionKey = req.headers['x-session-key'];
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid authorization header' });
  }
  
  if (!sessionKey) {
    return res.status(401).json({ error: 'Missing session key' });
  }
  
  const token = authHeader.substring(7);
  
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    
    // Verify session key matches
    if (decoded.sessionKey !== sessionKey) {
      console.warn(`🚫 Session key mismatch for user: ${decoded.userId}`);
      return res.status(401).json({ error: 'Invalid session' });
    }
    
    // Attach user info to request
    req.userId = decoded.userId;
    req.userPhone = decoded.phone;
    req.userRole = decoded.role;
    
    next();
  } catch (err) {
    console.warn(`🚫 JWT verification failed: ${err.message}`);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

// Generate JWT with session key
function generateTokens(user) {
  const sessionKey = crypto.randomBytes(16).toString('hex');
  
  const token = jwt.sign(
    { 
      userId: user.id,
      phone: user.phone,
      role: user.role,
      sessionKey: sessionKey
    },
    JWT_SECRET,
    { expiresIn: '7d' } // Token valid for 7 days
  );
  
  return { token, sessionKey };
}

// Apply rate limiting to all requests
app.use(rateLimit);
// Apply anti-scrape protection
app.use(antiScrape);
// Apply auth middleware to protected endpoints
app.use(requireAuth);

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
      notes || null
    ]);
    
    for (const it of items) {
      const [[{ uuid: itemId }]] = await conn.query(`SELECT UUID() AS uuid`);
      const productId = it.product_id || null;
      const qty = it.quantity || 0;
      const price = it.price_per_kg || 0;
      console.log('Inserting order_item:', { itemId, orderId, productId, qty, price, it });
      await conn.query(`
        INSERT INTO order_items (id, order_id, product_id, quantity, price_per_kg)
        VALUES (?, ?, ?, ?, ?)
      `, [itemId, orderId, productId, qty, price]);
    }
    
    await conn.commit();
    console.log('Order created:', orderId);
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
    
    console.log('Creating order:', { orderId, user_id, delivery_type, items: items.length });
    
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
      delivery_address || null,
      delivery_details || null,
      details.house_type || 'apartment',
      details.entrance || null,
      details.floor || null,
      details.apartment || null,
      details.intercom || null,
      details.intercom_broken || false,
      details.latitude || null,
      details.longitude || null,
      total,
      notes || null
    ]);

    for (const it of items) {
      const [[{ uuid: itemId }]] = await conn.query(`SELECT UUID() AS uuid`);
      const productId = it.product_id || null;
      const qty = it.quantity || 0;
      const price = it.price_per_kg || 0;
      console.log('Inserting item:', { itemId, orderId, productId, qty, price });
      await conn.query(`
        INSERT INTO order_items (id, order_id, product_id, quantity, price_per_kg)
        VALUES (?, ?, ?, ?, ?)
      `, [itemId, orderId, productId, qty, price]);
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

  // Generate JWT token and session key
  const { token, sessionKey } = generateTokens(user);
  
  // Return user data + tokens
  res.json({
    user: {
      id: user.id,
      phone: user.phone,
      first_name: user.first_name,
      last_name: user.last_name,
      middle_name: user.middle_name,
      role: user.role,
      is_verified: user.is_verified
    },
    token: token,
    sessionKey: sessionKey
  });
});

// Get current user info (for session validation)
app.get("/auth/me", async (req, res) => {
  // This endpoint is protected by requireAuth middleware
  // If we get here, req.userId is set
  
  const [rows] = await pool.query(
    "SELECT id, phone, first_name, last_name, middle_name, role, is_verified FROM users WHERE id = ?",
    [req.userId]
  );
  
  if (rows.length === 0) {
    return res.status(404).json({ error: "User not found" });
  }
  
  res.json(rows[0]);
});


const port = process.env.PORT || 3000;
const host = '0.0.0.0'; // слушаем все интерфейсы, не только 127.0.0.1
app.listen(port, host, () => console.log(`API listening on http://${host}:${port}`));
console.log("BOT TOKEN:", process.env.TG_BOT_TOKEN);
