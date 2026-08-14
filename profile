<?php
session_start();

// Protect profile page: only allow access when logged in
if (!isset($_SESSION['user_email'])) {
    header('Location: login');
    exit;
}

require_once __DIR__ . '/../config.php';

$currentEmail = $_SESSION['user_email'] ?? '';
$currentName = $_SESSION['user_name'] ?? '';
$currentDepartment = $_SESSION['user_department'] ?? '';
$currentRole = $_SESSION['user_role'] ?? '';
$userId = null;

$successMessage = '';
$errorMessage = '';
$departments = [];

// Fetch departments from database
if (defined('SUPABASE_URL') && defined('SUPABASE_ANON_KEY') && SUPABASE_URL !== '' && SUPABASE_ANON_KEY !== '') {
    $supabaseUrl = rtrim(SUPABASE_URL, '/');
    $supabaseKey = SUPABASE_ANON_KEY;

    $query = http_build_query([
        'select' => 'id,name',
        'order' => 'name.asc'
    ]);

    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL => $supabaseUrl . '/rest/v1/departments?' . $query,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            'apikey: ' . $supabaseKey,
            'Authorization: Bearer ' . $supabaseKey,
            'Accept: application/json',
        ],
    ]);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode === 200 && $response) {
        $departments = json_decode($response, true);
        if (!is_array($departments)) {
            $departments = [];
        }
    }
}

// Create uploads directory if it doesn't exist
$uploadsDir = __DIR__ . '/uploads/profile/';
if (!file_exists($uploadsDir)) {
    mkdir($uploadsDir, 0755, true);
}

// Get user data from Supabase
if (defined('SUPABASE_URL') && defined('SUPABASE_ANON_KEY') && SUPABASE_URL !== '' && SUPABASE_ANON_KEY !== '') {
    $supabaseUrl = rtrim(SUPABASE_URL, '/');
    $supabaseKey = SUPABASE_ANON_KEY;
    
    $query = http_build_query([
        'select' => 'id,full_name,email,department,role,profile_picture,signature',
        'email' => 'eq.' . urlencode($currentEmail),
        'limit' => 1,
    ]);
    
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL => $supabaseUrl . '/rest/v1/users?' . $query,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            'apikey: ' . $supabaseKey,
            'Authorization: Bearer ' . $supabaseKey,
            'Accept: application/json',
        ],
    ]);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode === 200 && $response) {
        $rows = json_decode($response, true);
        if (is_array($rows) && count($rows) > 0) {
            $userData = $rows[0];
            $userId = $userData['id'] ?? null;
            $currentName = $userData['full_name'] ?? $currentName;
            $currentDepartment = $userData['department'] ?? $currentDepartment;
            $currentRole = $userData['role'] ?? $currentRole;
            $profilePicture = $userData['profile_picture'] ?? '';
            $signature = $userData['signature'] ?? '';
        }
    }
}

// Handle form submissions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';
    
    if ($action === 'update_profile') {
        $fullName = trim($_POST['full_name'] ?? '');
        $email = trim($_POST['email'] ?? '');
        $department = $_POST['department'] ?? '';
        
        if (empty($fullName) || empty($email) || empty($department)) {
            $errorMessage = 'Please fill in all required fields.';
        } elseif (!defined('SUPABASE_URL') || !defined('SUPABASE_ANON_KEY') || SUPABASE_URL === '' || SUPABASE_ANON_KEY === '') {
            $errorMessage = 'Service is not configured. Please contact the administrator.';
        } else {
            $supabaseUrl = rtrim(SUPABASE_URL, '/');
            $supabaseKey = SUPABASE_ANON_KEY;
            
            $updateData = [
                'full_name' => $fullName,
                'email' => $email,
                'department' => $department
            ];
            
            $ch = curl_init();
            curl_setopt_array($ch, [
                CURLOPT_URL => $supabaseUrl . '/rest/v1/users?email=eq.' . urlencode($currentEmail),
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_CUSTOMREQUEST => 'PATCH',
                CURLOPT_POSTFIELDS => json_encode($updateData),
                CURLOPT_HTTPHEADER => [
                    'apikey: ' . $supabaseKey,
                    'Authorization: Bearer ' . $supabaseKey,
                    'Content-Type: application/json',
                    'Prefer: return=representation',
                ],
            ]);
            
            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);
            
                        if ($httpCode >= 200 && $httpCode < 300) {
                            $_SESSION['user_name'] = $fullName;
                            $_SESSION['user_email'] = $email;
                            $_SESSION['user_department'] = $department;
                            $currentName = $fullName;
                            $currentEmail = $email;
                            $currentDepartment = $department;
                            
                            // Reload profile picture after update
                            $query = http_build_query([
                                'select' => 'profile_picture',
                                'email' => 'eq.' . urlencode($email),
                                'limit' => 1,
                            ]);
                            
                            $ch2 = curl_init();
                            curl_setopt_array($ch2, [
                                CURLOPT_URL => $supabaseUrl . '/rest/v1/users?' . $query,
                                CURLOPT_RETURNTRANSFER => true,
                                CURLOPT_HTTPHEADER => [
                                    'apikey: ' . $supabaseKey,
                                    'Authorization: Bearer ' . $supabaseKey,
                                    'Accept: application/json',
                                ],
                            ]);
                            
                            $response2 = curl_exec($ch2);
                            $httpCode2 = curl_getinfo($ch2, CURLINFO_HTTP_CODE);
                            curl_close($ch2);
                            
                            if ($httpCode2 === 200 && $response2) {
                                $rows2 = json_decode($response2, true);
                                if (is_array($rows2) && count($rows2) > 0) {
                                    $profilePicture = $rows2[0]['profile_picture'] ?? '';
                                    $_SESSION['user_profile_picture'] = $profilePicture;
                                }
                            }
                            
                            $successMessage = 'Profile updated successfully!';
                        } else {
                            $errorMessage = 'Failed to update profile. Please try again.';
                        }
        }
    } elseif ($action === 'change_password') {
        $currentPassword = $_POST['current_password'] ?? '';
        $newPassword = $_POST['new_password'] ?? '';
        $confirmPassword = $_POST['confirm_password'] ?? '';
        
        if (empty($currentPassword) || empty($newPassword) || empty($confirmPassword)) {
            $errorMessage = 'Please fill in all password fields.';
        } elseif ($newPassword !== $confirmPassword) {
            $errorMessage = 'New passwords do not match.';
        } elseif (strlen($newPassword) < 6) {
            $errorMessage = 'New password must be at least 6 characters long.';
        } elseif (!defined('SUPABASE_URL') || !defined('SUPABASE_ANON_KEY') || SUPABASE_URL === '' || SUPABASE_ANON_KEY === '') {
            $errorMessage = 'Service is not configured. Please contact the administrator.';
        } else {
            // Verify current password
            $supabaseUrl = rtrim(SUPABASE_URL, '/');
            $supabaseKey = SUPABASE_ANON_KEY;
            
            $query = http_build_query([
                'select' => 'temp_password',
                'email' => 'eq.' . urlencode($currentEmail),
                'limit' => 1,
            ]);
            
            $ch = curl_init();
            curl_setopt_array($ch, [
                CURLOPT_URL => $supabaseUrl . '/rest/v1/users?' . $query,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_HTTPHEADER => [
                    'apikey: ' . $supabaseKey,
                    'Authorization: Bearer ' . $supabaseKey,
                    'Accept: application/json',
                ],
            ]);
            
            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);
            
            if ($httpCode === 200 && $response) {
                $rows = json_decode($response, true);
                if (is_array($rows) && count($rows) > 0) {
                    $storedPassword = $rows[0]['temp_password'] ?? '';
                    
                    if (hash_equals($storedPassword, $currentPassword)) {
                        // Update password
                        $updateData = ['temp_password' => $newPassword];
                        
                        $ch = curl_init();
                        curl_setopt_array($ch, [
                            CURLOPT_URL => $supabaseUrl . '/rest/v1/users?email=eq.' . urlencode($currentEmail),
                            CURLOPT_RETURNTRANSFER => true,
                            CURLOPT_CUSTOMREQUEST => 'PATCH',
                            CURLOPT_POSTFIELDS => json_encode($updateData),
                            CURLOPT_HTTPHEADER => [
                                'apikey: ' . $supabaseKey,
                                'Authorization: Bearer ' . $supabaseKey,
                                'Content-Type: application/json',
                                'Prefer: return=representation',
                            ],
                        ]);
                        
                        $response = curl_exec($ch);
                        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
                        curl_close($ch);
                        
                        if ($httpCode >= 200 && $httpCode < 300) {
                            $successMessage = 'Password changed successfully!';
                        } else {
                            $errorMessage = 'Failed to change password. Please try again.';
                        }
                    } else {
                        $errorMessage = 'Current password is incorrect.';
                    }
                } else {
                    $errorMessage = 'User not found.';
                }
            } else {
                $errorMessage = 'Failed to verify current password.';
            }
        }
    } elseif ($action === 'upload_picture') {
        if (isset($_FILES['profile_picture']) && $_FILES['profile_picture']['error'] === UPLOAD_ERR_OK) {
            $file = $_FILES['profile_picture'];
            $allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
            $maxSize = 5 * 1024 * 1024; // 5MB
            
            if (!in_array($file['type'], $allowedTypes)) {
                $errorMessage = 'Invalid file type. Please upload a JPEG, PNG, GIF, or WebP image.';
            } elseif ($file['size'] > $maxSize) {
                $errorMessage = 'File size exceeds 5MB limit.';
            } else {
                $extension = pathinfo($file['name'], PATHINFO_EXTENSION);
                $filename = 'profile_' . md5($currentEmail . time()) . '.' . $extension;
                $filepath = $uploadsDir . $filename;
                
                if (move_uploaded_file($file['tmp_name'], $filepath)) {
                    $relativePath = 'uploads/profile/' . $filename;
                    
                    // Delete old profile picture if exists
                    if (!empty($profilePicture) && file_exists(__DIR__ . '/uploads/profile/' . basename($profilePicture))) {
                        @unlink(__DIR__ . '/uploads/profile/' . basename($profilePicture));
                    }
                    
                    // Update in Supabase
                    if (defined('SUPABASE_URL') && defined('SUPABASE_ANON_KEY') && SUPABASE_URL !== '' && SUPABASE_ANON_KEY !== '') {
                        $supabaseUrl = rtrim(SUPABASE_URL, '/');
                        $supabaseKey = SUPABASE_ANON_KEY;
                        
                        $updateData = ['profile_picture' => $relativePath];
                        
                        $ch = curl_init();
                        curl_setopt_array($ch, [
                            CURLOPT_URL => $supabaseUrl . '/rest/v1/users?email=eq.' . urlencode($currentEmail),
                            CURLOPT_RETURNTRANSFER => true,
                            CURLOPT_CUSTOMREQUEST => 'PATCH',
                            CURLOPT_POSTFIELDS => json_encode($updateData),
                            CURLOPT_HTTPHEADER => [
                                'apikey: ' . $supabaseKey,
                                'Authorization: Bearer ' . $supabaseKey,
                                'Content-Type: application/json',
                                'Prefer: return=representation',
                            ],
                        ]);
                        
                        $response = curl_exec($ch);
                        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
                        curl_close($ch);
                        
                        if ($httpCode >= 200 && $httpCode < 300) {
                            $profilePicture = $relativePath;
                            $_SESSION['user_profile_picture'] = $relativePath;
                            $successMessage = 'Profile picture updated successfully!';
                        } else {
                            $errorMessage = 'Failed to update profile picture in database.';
                        }
                    } else {
                        $profilePicture = $relativePath;
                        $successMessage = 'Profile picture uploaded successfully!';
                    }
                } else {
                    $errorMessage = 'Failed to upload file. Please try again.';
                }
            }
        } else {
            $errorMessage = 'No file uploaded or upload error occurred.';
        }
    } elseif ($action === 'save_signature') {
        $signatureData = $_POST['signature_data'] ?? '';

        if (empty($signatureData)) {
            $errorMessage = 'No signature data provided.';
        } else {
            // Update in Supabase
            if (defined('SUPABASE_URL') && defined('SUPABASE_ANON_KEY') && SUPABASE_URL !== '' && SUPABASE_ANON_KEY !== '') {
                $supabaseUrl = rtrim(SUPABASE_URL, '/');
                $supabaseKey = SUPABASE_ANON_KEY;

                $updateData = ['signature' => $signatureData];

                $ch = curl_init();
                curl_setopt_array($ch, [
                    CURLOPT_URL => $supabaseUrl . '/rest/v1/users?email=eq.' . urlencode($currentEmail),
                    CURLOPT_RETURNTRANSFER => true,
                    CURLOPT_CUSTOMREQUEST => 'PATCH',
                    CURLOPT_POSTFIELDS => json_encode($updateData),
                    CURLOPT_HTTPHEADER => [
                        'apikey: ' . $supabaseKey,
                        'Authorization: Bearer ' . $supabaseKey,
                        'Content-Type: application/json',
                        'Prefer: return=representation',
                    ],
                ]);

                $response = curl_exec($ch);
                $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
                curl_close($ch);

                if ($httpCode >= 200 && $httpCode < 300) {
                    $signature = $signatureData;
                    $_SESSION['user_signature'] = $signatureData;
                    $successMessage = 'Signature saved successfully!';
                } else {
                    $errorMessage = 'Failed to save signature in database. Error: ' . $response;
                }
            } else {
                $signature = $signatureData;
                $successMessage = 'Signature saved successfully!';
            }
        }
    } elseif ($action === 'delete_signature') {
        // Update in Supabase
        if (defined('SUPABASE_URL') && defined('SUPABASE_ANON_KEY') && SUPABASE_URL !== '' && SUPABASE_ANON_KEY !== '') {
            $supabaseUrl = rtrim(SUPABASE_URL, '/');
            $supabaseKey = SUPABASE_ANON_KEY;

            $updateData = ['signature' => null];

            $ch = curl_init();
            curl_setopt_array($ch, [
                CURLOPT_URL => $supabaseUrl . '/rest/v1/users?email=eq.' . urlencode($currentEmail),
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_CUSTOMREQUEST => 'PATCH',
                CURLOPT_POSTFIELDS => json_encode($updateData),
                CURLOPT_HTTPHEADER => [
                    'apikey: ' . $supabaseKey,
                    'Authorization: Bearer ' . $supabaseKey,
                    'Content-Type: application/json',
                    'Prefer: return=representation',
                ],
            ]);

            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            if ($httpCode >= 200 && $httpCode < 300) {
                $signature = '';
                unset($_SESSION['user_signature']);
                $successMessage = 'Signature deleted successfully!';
            } else {
                $errorMessage = 'Failed to delete signature from database.';
            }
        } else {
            $signature = '';
            $successMessage = 'Signature deleted successfully!';
        }
    }
}

// Get updated profile picture if needed
if (!isset($profilePicture)) {
    $profilePicture = '';
}

// Get updated signature if needed
if (!isset($signature)) {
    $signature = '';
}

// Store profile picture in session for navbar use
if (!empty($profilePicture)) {
    $_SESSION['user_profile_picture'] = $profilePicture;
} elseif (isset($_SESSION['user_profile_picture'])) {
    $profilePicture = $_SESSION['user_profile_picture'];
}

// Store signature in session
if (!empty($signature)) {
    $_SESSION['user_signature'] = $signature;
} elseif (isset($_SESSION['user_signature'])) {
    $signature = $_SESSION['user_signature'];
}

// Verify profile picture file exists
if (!empty($profilePicture)) {
    $filename = basename($profilePicture);
    $picturePath = __DIR__ . '/uploads/profile/' . $filename;
    if (!file_exists($picturePath)) {
        $profilePicture = '';
        unset($_SESSION['user_profile_picture']);
    }
}

// Note: Signature is stored as base64 in database, no file verification needed
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Work Card System - Profile</title>
    
    <!-- Bootstrap 5 CSS CDN -->
    <link
        href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
        rel="stylesheet"
        integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH"
        crossorigin="anonymous"
    />
    
    <!-- Bootstrap Icons -->
    <link
        rel="stylesheet"
        href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css"
    />
    
    <!-- Custom CSS -->
    <link rel="stylesheet" href="sidebar.css" />
    <link rel="stylesheet" href="dashboard.css" />
    <link rel="icon" type="image/svg+xml" href="https://www.texolenergies.com/assets/Texol_icon-AiPT1Z13.png" />
    
    <style>
        .profile-picture-container {
            position: relative;
            display: inline-block;
            margin-bottom: 20px;
        }
        .profile-picture {
            width: 150px;
            height: 150px;
            border-radius: 50%;
            object-fit: cover;
            border: 4px solid #e5e7eb;
            cursor: pointer;
            transition: border-color 0.3s;
        }
        .profile-picture:hover {
            border-color: #4f46e5;
        }
        .profile-picture-placeholder {
            width: 150px;
            height: 150px;
            border-radius: 50%;
            background: linear-gradient(135deg, #4f46e5, #6366f1);
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 48px;
            font-weight: bold;
            border: 4px solid #e5e7eb;
            cursor: pointer;
            transition: border-color 0.3s;
        }
        .profile-picture-placeholder:hover {
            border-color: #4f46e5;
        }
        .upload-overlay {
            position: absolute;
            bottom: 0;
            right: 0;
            background: #4f46e5;
            color: white;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
        }
        #profilePictureInput {
            display: none;
        }
        .signature-canvas {
            border: 2px dashed #dee2e6;
            border-radius: 8px;
            background-color: #f8f9fa;
            cursor: crosshair;
        }
        .signature-canvas:hover {
            border-color: #0d6efd;
        }
    </style>
</head>
<body class="dashboard-body">
    <div class="d-flex" id="layoutWrapper">
        <?php
        $activeMenu = 'profile';
        include __DIR__ . '/partials/sidebar.php';
        ?>
        
        <div class="main-content flex-grow-1 d-flex flex-column">
            <nav class="navbar navbar-expand-lg navbar-light bg-white border-bottom main-navbar px-3 px-lg-4">
                <button
                    class="btn btn-outline-secondary d-lg-none me-2"
                    id="sidebarToggleBtn"
                    type="button"
                    aria-label="Toggle sidebar"
                >
                    <i class="bi bi-list"></i>
                </button>
                
                <a class="navbar-brand fw-semibold d-none d-sm-inline d-flex align-items-center gap-2" href="#">
                  
                    <span id="pageTitle">Profile</span>
                </a>
                
                <div class="ms-auto d-flex align-items-center gap-3">
                    <?php include __DIR__ . '/partials/navbar_user.php'; ?>
                </div>
            </nav>
            
            <main class="flex-grow-1 py-4 py-md-5 px-3 px-lg-4 content-area">
                <section class="mb-4">
                    <h1 class="h4 fw-semibold mb-1">My Profile</h1>
                    <p class="text-muted small mb-4">Manage your account settings and preferences.</p>
                    
                    <?php if (!empty($successMessage)) : ?>
                        <div class="alert alert-success alert-dismissible fade show" role="alert">
                            <?php echo htmlspecialchars($successMessage, ENT_QUOTES, 'UTF-8'); ?>
                            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
                        </div>
                    <?php endif; ?>
                    
                    <?php if (!empty($errorMessage)) : ?>
                        <div class="alert alert-danger alert-dismissible fade show" role="alert">
                            <?php echo htmlspecialchars($errorMessage, ENT_QUOTES, 'UTF-8'); ?>
                            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
                        </div>
                    <?php endif; ?>
                    
                    <div class="row g-4">
                        <!-- Left Column: Profile Picture and Signature -->
                        <div class="col-12 col-md-4">
                            <!-- Profile Picture Section -->
                            <div class="card border-0 shadow-sm mb-4">
                                <div class="card-body text-center">
                                    <div class="profile-picture-container">
                                        <?php if (!empty($profilePicture)) : ?>
                                            <img src="<?php echo htmlspecialchars($profilePicture, ENT_QUOTES, 'UTF-8'); ?>"
                                                 alt="Profile Picture"
                                                 class="profile-picture"
                                                 id="profilePictureDisplay">
                                        <?php else : ?>
                                            <div class="profile-picture-placeholder" id="profilePicturePlaceholder">
                                                <?php echo htmlspecialchars($initials, ENT_QUOTES, 'UTF-8'); ?>
                                            </div>
                                        <?php endif; ?>
                                        <div class="upload-overlay" onclick="document.getElementById('profilePictureInput').click()">
                                            <i class="bi bi-camera-fill"></i>
                                        </div>
                                    </div>
                                    <input type="file"
                                           id="profilePictureInput"
                                           name="profile_picture"
                                           accept="image/jpeg,image/png,image/gif,image/webp"
                                           form="profilePictureForm">
                                    <form id="profilePictureForm" method="post" enctype="multipart/form-data" style="display: none;">
                                        <input type="hidden" name="action" value="upload_picture">
                                    </form>
                                    <p class="small text-muted mt-2">Click to upload a new profile picture</p>
                                    <p class="small text-muted">Max size: 5MB (JPEG, PNG, GIF, WebP)</p>
                                </div>
                            </div>

                            <!-- Signature Section -->
                            <div class="card border-0 shadow-sm">
                                <div class="card-header bg-white py-3 px-3 px-md-4">
                                    <h2 class="h6 mb-0 fw-semibold">Signature</h2>
                                </div>
                                <div class="card-body text-center">
                                    <div class="signature-container mb-3">
                                        <?php if (!empty($signature)) : ?>
                                            <img id="signaturePreview"
                                                 src="<?php echo htmlspecialchars($signature, ENT_QUOTES, 'UTF-8'); ?>"
                                                 alt="Signature"
                                                 class="signature-display"
                                                 style="max-width: 100%; max-height: 100px; border: 1px solid #e5e7eb; border-radius: 4px; background: white;">
                                        <?php else : ?>
                                            <div id="signaturePlaceholder" class="signature-placeholder" style="width: 100%; height: 100px; border: 2px dashed #e5e7eb; border-radius: 4px; display: flex; align-items: center; justify-content: center; color: #9ca3af; font-size: 14px;">
                                                No signature
                                            </div>
                                        <?php endif; ?>
                                    </div>
                                    <input type="hidden" id="signatureData" name="signature_data" value="<?php echo htmlspecialchars($signature, ENT_QUOTES, 'UTF-8'); ?>">
                                    <button type="button" class="btn btn-sm btn-outline-primary" id="signBtn" data-bs-toggle="modal" data-bs-target="#signatureModal">
                                        <i class="bi bi-pen me-1"></i> Sign
                                    </button>
                                    <?php if (!empty($signature)) : ?>
                                        <button type="button" class="btn btn-sm btn-outline-danger ms-2" id="removeSignatureBtn">
                                            <i class="bi bi-trash me-1"></i> Remove
                                        </button>
                                    <?php endif; ?>
                                    <form id="signatureForm" method="post" style="display: none;">
                                        <input type="hidden" name="action" value="save_signature">
                                        <input type="hidden" id="signatureDataInput" name="signature_data">
                                    </form>
                                </div>
                            </div>
                        </div>

                        <!-- Right Column: Profile Details and Change Password -->
                        <div class="col-12 col-md-8">
                            <div class="card border-0 shadow-sm mb-4">
                                <div class="card-header bg-white py-3 px-3 px-md-4">
                                    <h2 class="h6 mb-0 fw-semibold">Personal Information</h2>
                                </div>
                                <div class="card-body px-3 px-md-4">
                                    <form method="post" action="profile">
                                        <input type="hidden" name="action" value="update_profile">
                                        
                                        <div class="row g-3">
                                            <div class="col-12">
                                                <label class="form-label small fw-semibold" for="full_name">Full Name</label>
                                                <input type="text" 
                                                       class="form-control form-control-sm" 
                                                       id="full_name" 
                                                       name="full_name" 
                                                       value="<?php echo htmlspecialchars($currentName, ENT_QUOTES, 'UTF-8'); ?>" 
                                                       required>
                                            </div>
                                            
                                            <div class="col-12 col-md-6">
                                                <label class="form-label small fw-semibold" for="email">Email</label>
                                                <input type="email" 
                                                       class="form-control form-control-sm" 
                                                       id="email" 
                                                       name="email" 
                                                       value="<?php echo htmlspecialchars($currentEmail, ENT_QUOTES, 'UTF-8'); ?>" 
                                                       required>
                                            </div>
                                            
                                            <div class="col-12 col-md-6">
                                                <label class="form-label small fw-semibold" for="department">Department</label>
                                                <select class="form-select form-select-sm" id="department" name="department" required>
                                                    <option value="">Select department</option>
                                                    <?php foreach ($departments as $dept): ?>
                                                        <option value="<?php echo htmlspecialchars($dept['name'], ENT_QUOTES, 'UTF-8'); ?>" <?php echo $currentDepartment === $dept['name'] ? 'selected' : ''; ?>>
                                                            <?php echo htmlspecialchars($dept['name'], ENT_QUOTES, 'UTF-8'); ?>
                                                        </option>
                                                    <?php endforeach; ?>
                                                </select>
                                            </div>
                                            
                                            <div class="col-12">
                                                <label class="form-label small fw-semibold">Role</label>
                                                <input type="text" 
                                                       class="form-control form-control-sm" 
                                                       value="<?php echo htmlspecialchars($currentRole, ENT_QUOTES, 'UTF-8'); ?>" 
                                                       disabled>
                                                <small class="text-muted">Role cannot be changed from profile page</small>
                                            </div>
                                            
                                            <div class="col-12 d-flex justify-content-end mt-3">
                                                <button type="submit" class="btn btn-sm btn-primary">
                                                    <i class="bi bi-save me-1"></i> Save Changes
                                                </button>
                                            </div>
                                        </div>
                                    </form>
                                </div>
                            </div>
                            
                            <!-- Change Password Section -->
                            <div class="card border-0 shadow-sm">
                                <div class="card-header bg-white py-3 px-3 px-md-4">
                                    <h2 class="h6 mb-0 fw-semibold">Change Password</h2>
                                </div>
                                <div class="card-body px-3 px-md-4">
                                    <form method="post" action="profile" id="changePasswordForm">
                                        <input type="hidden" name="action" value="change_password">
                                        
                                        <div class="row g-3">
                                            <div class="col-12">
                                                <label class="form-label small fw-semibold" for="current_password">Current Password</label>
                                                <input type="password" 
                                                       class="form-control form-control-sm" 
                                                       id="current_password" 
                                                       name="current_password" 
                                                       required>
                                            </div>
                                            
                                            <div class="col-12 col-md-6">
                                                <label class="form-label small fw-semibold" for="new_password">New Password</label>
                                                <input type="password" 
                                                       class="form-control form-control-sm" 
                                                       id="new_password" 
                                                       name="new_password" 
                                                       minlength="6"
                                                       required>
                                                <small class="text-muted">Minimum 6 characters</small>
                                            </div>
                                            
                                            <div class="col-12 col-md-6">
                                                <label class="form-label small fw-semibold" for="confirm_password">Confirm New Password</label>
                                                <input type="password" 
                                                       class="form-control form-control-sm" 
                                                       id="confirm_password" 
                                                       name="confirm_password" 
                                                       minlength="6"
                                                       required>
                                            </div>
                                            
                                            <div class="col-12 d-flex justify-content-end mt-3">
                                                <button type="submit" class="btn btn-sm btn-primary">
                                                    <i class="bi bi-key me-1"></i> Change Password
                                                </button>
                                            </div>
                                        </div>
                                    </form>
                                </div>
                            </div>
                        </div>
                    </div>
                </section>
            </main>
        </div>
    </div>

    <!-- Signature Modal -->
    <div class="modal fade" id="signatureModal" tabindex="-1" aria-labelledby="signatureModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="signatureModalLabel">
                        <i class="bi bi-pen me-2"></i>Draw Your Signature
                    </h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <div class="mb-3">
                        <label class="form-label fw-semibold">Draw your signature below:</label>
                        <canvas id="signatureCanvas" class="signature-canvas w-100" style="background: white; border: 2px dashed #dee2e6; border-radius: 8px;" height="150"></canvas>
                    </div>
                    <div class="d-flex gap-2">
                        <button type="button" class="btn btn-sm btn-outline-danger" id="clearSignatureBtn">
                            <i class="bi bi-x-circle me-1"></i>Clear
                        </button>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" class="btn btn-primary" id="saveSignatureBtn">
                        <i class="bi bi-check me-1"></i>Save Signature
                    </button>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Bootstrap JS Bundle CDN -->
    <script
        src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
        integrity="sha384-YvpcrYf0tY3lHB60NNkmXc5s9fDVZLESaAA55NDzOxhy9GkcIdslK1eN7N6jIeHz"
        crossorigin="anonymous"
    ></script>
    
    <!-- App JS -->
    <script src="app.js"></script>
    
    <script>
        // Handle profile picture upload
        const profilePictureInput = document.getElementById('profilePictureInput');
        const profilePictureForm = document.getElementById('profilePictureForm');

        if (profilePictureInput) {
            profilePictureInput.addEventListener('change', function() {
                if (this.files && this.files[0]) {
                    // Add file input to form
                    const existingInput = profilePictureForm.querySelector('input[type="file"]');
                    if (existingInput) {
                        existingInput.remove();
                    }
                    profilePictureForm.appendChild(this.cloneNode(true));

                    // Submit form
                    profilePictureForm.submit();
                }
            });
        }

        // Signature canvas
        const canvas = document.getElementById('signatureCanvas');
        const ctx = canvas.getContext('2d');
        let isDrawing = false;
        let lastX = 0;
        let lastY = 0;

        // Resize canvas to match display size
        function resizeCanvas() {
            if (!canvas) return;
            const rect = canvas.getBoundingClientRect();
            const targetHeight = Math.max(canvas.getAttribute('height') || 150, rect.height);
            canvas.width = rect.width;
            canvas.height = targetHeight;
        }
        window.addEventListener('resize', resizeCanvas);

        // Drawing functions
        if (canvas) {
            canvas.addEventListener('mousedown', startDrawing);
            canvas.addEventListener('mousemove', draw);
            canvas.addEventListener('mouseup', stopDrawing);
            canvas.addEventListener('mouseout', stopDrawing);

            // Touch support
            canvas.addEventListener('touchstart', handleTouchStart);
            canvas.addEventListener('touchmove', handleTouchMove);
            canvas.addEventListener('touchend', stopDrawing);
        }

        function startDrawing(e) {
            isDrawing = true;
            [lastX, lastY] = [e.offsetX, e.offsetY];
        }

        function draw(e) {
            if (!isDrawing) return;
            ctx.beginPath();
            ctx.moveTo(lastX, lastY);
            ctx.lineTo(e.offsetX, e.offsetY);
            ctx.strokeStyle = '#000';
            ctx.lineWidth = 2;
            ctx.lineCap = 'round';
            ctx.stroke();
            [lastX, lastY] = [e.offsetX, e.offsetY];
        }

        function stopDrawing() {
            isDrawing = false;
        }

        function handleTouchStart(e) {
            e.preventDefault();
            const touch = e.touches[0];
            const rect = canvas.getBoundingClientRect();
            lastX = touch.clientX - rect.left;
            lastY = touch.clientY - rect.top;
            isDrawing = true;
        }

        function handleTouchMove(e) {
            e.preventDefault();
            if (!isDrawing) return;
            const touch = e.touches[0];
            const rect = canvas.getBoundingClientRect();
            const x = touch.clientX - rect.left;
            const y = touch.clientY - rect.top;
            ctx.beginPath();
            ctx.moveTo(lastX, lastY);
            ctx.lineTo(x, y);
            ctx.strokeStyle = '#000';
            ctx.lineWidth = 2;
            ctx.lineCap = 'round';
            ctx.stroke();
            [lastX, lastY] = [x, y];
        }

        // Initialize signature modal
        const signatureModal = document.getElementById('signatureModal');
        if (signatureModal) {
            signatureModal.addEventListener('shown.bs.modal', function() {
                setTimeout(() => {
                    resizeCanvas();
                }, 100);
            });
        }

        // Clear signature
        const clearSignatureBtn = document.getElementById('clearSignatureBtn');
        if (clearSignatureBtn) {
            clearSignatureBtn.addEventListener('click', function() {
                ctx.clearRect(0, 0, canvas.width, canvas.height);
            });
        }

        // Save signature
        const saveSignatureBtn = document.getElementById('saveSignatureBtn');
        if (saveSignatureBtn) {
            saveSignatureBtn.addEventListener('click', function() {
                const signatureData = canvas.toDataURL('image/png');

                // Save to hidden input
                document.getElementById('signatureDataInput').value = signatureData;

                // Submit form
                document.getElementById('signatureForm').submit();
            });
        }

        // Remove signature
        const removeSignatureBtn = document.getElementById('removeSignatureBtn');
        if (removeSignatureBtn) {
            removeSignatureBtn.addEventListener('click', function() {
                if (confirm('Are you sure you want to delete your signature?')) {
                    // Create a form to delete signature
                    const deleteForm = document.createElement('form');
                    deleteForm.method = 'post';
                    deleteForm.action = 'profile';

                    const actionInput = document.createElement('input');
                    actionInput.type = 'hidden';
                    actionInput.name = 'action';
                    actionInput.value = 'delete_signature';

                    deleteForm.appendChild(actionInput);
                    document.body.appendChild(deleteForm);
                    deleteForm.submit();
                }
            });
        }

        // Password confirmation validation
        const changePasswordForm = document.getElementById('changePasswordForm');
        if (changePasswordForm) {
            changePasswordForm.addEventListener('submit', function(e) {
                const newPassword = document.getElementById('new_password').value;
                const confirmPassword = document.getElementById('confirm_password').value;

                if (newPassword !== confirmPassword) {
                    e.preventDefault();
                    alert('New passwords do not match!');
                    return false;
                }
            });
        }
    </script>
</body>
</html>
