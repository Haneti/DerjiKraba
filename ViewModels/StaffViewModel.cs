using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using AvaloniaApplication1.Models;
using AvaloniaApplication1.Services;
using AvaloniaApplication1.Helpers;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AvaloniaApplication1.ViewModels
{
    public partial class StaffViewModel : ViewModelBase
    {
        private readonly ApiService _apiService;
        private readonly User _currentUser;

        [ObservableProperty]
        private ObservableCollection<User> _allUsers = new();

        [ObservableProperty]
        private User? _selectedUser;

        [ObservableProperty]
        private string _newPhone = string.Empty;

        [ObservableProperty]
        private string _newFirstName = string.Empty;

        [ObservableProperty]
        private string _newLastName = string.Empty;

        [ObservableProperty]
        private string _newMiddleName = string.Empty;

        [ObservableProperty]
        private string _selectedRole = "employee";

        [ObservableProperty]
        private bool _isCreatingNew = false;

        [ObservableProperty]
        private string _errorMessage = string.Empty;

        [ObservableProperty]
        private bool _isLoading = false;

        public StaffViewModel(User currentUser)
        {
            _currentUser = currentUser;
            _apiService = new ApiService();
            SelectedRole = "employee";
            _ = LoadAllUsersAsync();
        }

        private async Task LoadAllUsersAsync()
        {
            IsLoading = true;
            ErrorMessage = string.Empty;

            try
            {
                var users = await _apiService.GetAllUsersAsync();
                
                AllUsers.Clear();
                foreach (var user in users.OrderBy(u => u.LastName))
                {
                    AllUsers.Add(user);
                }

                Console.WriteLine($"✅ Loaded {AllUsers.Count} users for staff management");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error loading users: {ex.Message}");
                ErrorMessage = "Ошибка загрузки списка пользователей";
            }
            finally
            {
                IsLoading = false;
            }
        }

        [RelayCommand]
        private void ToggleCreateMode()
        {
            IsCreatingNew = !IsCreatingNew;
            if (!IsCreatingNew)
            {
                ClearNewUserForm();
            }
        }

        [RelayCommand]
        private void ClearNewUserForm()
        {
            NewPhone = string.Empty;
            NewFirstName = string.Empty;
            NewLastName = string.Empty;
            NewMiddleName = string.Empty;
            SelectedRole = "employee";
            ErrorMessage = string.Empty;
        }

        [RelayCommand]
        private async Task CreateStaffAccountAsync()
        {
            if (string.IsNullOrWhiteSpace(NewPhone))
            {
                ErrorMessage = "Введите номер телефона";
                return;
            }

            if (string.IsNullOrWhiteSpace(NewFirstName) || string.IsNullOrWhiteSpace(NewLastName))
            {
                ErrorMessage = "Введите имя и фамилию";
                return;
            }

            // Check if user already exists
            var existingUser = AllUsers.FirstOrDefault(u => u.Phone == PhoneFormatter.NormalizeForApi(NewPhone));
            if (existingUser != null)
            {
                ErrorMessage = $"Пользователь с таким телефоном уже существует: {existingUser.FullName}";
                return;
            }

            IsLoading = true;
            ErrorMessage = string.Empty;

            try
            {
                var normalizedPhone = PhoneFormatter.NormalizeForApi(NewPhone);
                var newUser = await _apiService.CreateStaffAsync(
                    normalizedPhone,
                    NewFirstName.Trim(),
                    NewLastName.Trim(),
                    NewMiddleName.Trim(),
                    SelectedRole
                );

                if (newUser != null)
                {
                    Console.WriteLine($"✅ Staff account created: {newUser.FullName} ({newUser.Phone}), Role: {newUser.Role}");
                    AllUsers.Add(newUser);
                    IsCreatingNew = false;
                    ClearNewUserForm();
                }
                else
                {
                    ErrorMessage = "Ошибка при создании аккаунта";
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Create staff error: {ex.Message}");
                ErrorMessage = $"Ошибка: {ex.Message}";
            }
            finally
            {
                IsLoading = false;
            }
        }

        [RelayCommand]
        private async Task PromoteToEmployeeAsync()
        {
            if (SelectedUser == null)
            {
                ErrorMessage = "Выберите пользователя из списка";
                return;
            }

            await ChangeUserRoleAsync("employee");
        }

        [RelayCommand]
        private async Task PromoteToOwnerAsync()
        {
            if (SelectedUser == null)
            {
                ErrorMessage = "Выберите пользователя из списка";
                return;
            }

            await ChangeUserRoleAsync("owner");
        }

        [RelayCommand]
        private async Task DemoteUserAsync()
        {
            if (SelectedUser == null)
            {
                ErrorMessage = "Выберите пользователя из списка";
                return;
            }

            string newRole = SelectedUser.Role switch
            {
                "owner" => "employee",
                "employee" => "client",
                _ => "client"
            };

            await ChangeUserRoleAsync(newRole);
        }

        private async Task ChangeUserRoleAsync(string newRole)
        {
            if (SelectedUser == null) return;

            IsLoading = true;
            ErrorMessage = string.Empty;

            try
            {
                var success = await _apiService.UpdateUserRoleAsync(SelectedUser.Id, newRole);

                if (success)
                {
                    Console.WriteLine($"✅ User role updated: {SelectedUser.FullName} → {newRole}");
                    
                    // Update the user in the list
                    var index = AllUsers.IndexOf(SelectedUser);
                    if (index >= 0)
                    {
                        AllUsers.RemoveAt(index);
                        SelectedUser.Role = newRole;
                        AllUsers.Insert(index, SelectedUser);
                    }
                    
                    SelectedUser = null; // Deselect after update
                }
                else
                {
                    ErrorMessage = "Ошибка при обновлении роли";
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Update role error: {ex.Message}");
                ErrorMessage = $"Ошибка: {ex.Message}";
            }
            finally
            {
                IsLoading = false;
            }
        }

        [RelayCommand]
        private void RefreshUsers()
        {
            _ = LoadAllUsersAsync();
        }
    }
}
