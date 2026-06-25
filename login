<?php
session_start();

require_once __DIR__ . '/../config.php';

// Check if user is already logged in
if (isset($_SESSION['user_email'])) {
    header('Location: index');
    exit;
}

// Check for remember me cookie
if (isset($_COOKIE['texol_remember']) && !isset($_SESSION['user_email'])) {
    $rememberToken = $_COOKIE['texol_remember'];
    
    if (defined('SUPABASE_URL') && defined('SUPABASE_ANON_KEY') && SUPABASE_URL !== '' && SUPABASE_ANON_KEY !== '') {
        $supabaseUrl = rtrim(SUPABASE_URL, '/');
        $supabaseKey = SUPABASE_ANON_KEY;
        
        // Query user by remember token (we'll store this in a cookie, but verify against email)
        // For security, we'll use email as the token identifier
        $email = base64_decode($rememberToken);
        
        if ($email && filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $query = http_build_query([
                'select' => 'id,full_name,email,department,role,status,profile_picture',
                'email'  => 'eq.' . urlencode($email),
                'status' => 'eq.active',
                'limit'  => 1,
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
                    $user = $rows[0];
                    $_SESSION['user_email'] = $user['email'] ?? $email;
                    $_SESSION['user_name'] = $user['full_name'] ?? '';
                    $_SESSION['user_role'] = $user['role'] ?? '';
                    $_SESSION['user_department'] = $user['department'] ?? '';
                    
                    // Load profile picture if available
                    if (isset($user['profile_picture']) && !empty($user['profile_picture'])) {
                        $_SESSION['user_profile_picture'] = $user['profile_picture'];
                    }

                    header('Location:  index');
                    exit;
                }
            }
        }
    }
}

$error = '';
$rememberEmail = isset($_COOKIE['texol_remember']) ? base64_decode($_COOKIE['texol_remember']) : '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = isset($_POST['email']) ? trim($_POST['email']) : '';
    $password = isset($_POST['password']) ? $_POST['password'] : '';
    $rememberMe = isset($_POST['remember_me']) && $_POST['remember_me'] === '1';

    if ($email === '' || $password === '') {
        $error = 'Please enter both email and password.';
    } elseif (! defined('SUPABASE_URL') || ! defined('SUPABASE_ANON_KEY') || SUPABASE_URL === '' || SUPABASE_ANON_KEY === '') {
        $error = 'Login service is not configured. Please contact the administrator.';
    } else {
        $supabaseUrl = rtrim(SUPABASE_URL, '/');
        $supabaseKey = SUPABASE_ANON_KEY;

        // Build REST query to Supabase "users" table
        $query = http_build_query([
            'select' => 'id,full_name,email,department,role,status,temp_password,profile_picture',
            'email'  => 'eq.' . $email,
            'status' => 'eq.active',
            'limit'  => 1,
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
        $curlError = curl_error($ch);
        curl_close($ch);

        if ($response === false || $httpCode >= 400) {
            // Avoid leaking backend details to the user
            $error = 'Unable to contact login service. Please try again later.';
        } else {
            $rows = json_decode($response, true);

            if (! is_array($rows) || count($rows) === 0) {
                $error = 'Invalid email or password.';
            } else {
                $user = $rows[0];
                $storedPassword = $user['temp_password'] ?? '';

                if (! hash_equals($storedPassword, $password)) {
                    $error = 'Invalid email or password.';
                } else {
                    // Successful login: store user info in session
                    $_SESSION['user_email'] = $user['email'] ?? $email;
                    $_SESSION['user_name'] = $user['full_name'] ?? '';
                    $_SESSION['user_role'] = $user['role'] ?? '';
                    $_SESSION['user_department'] = $user['department'] ?? '';
                    
                    // Load profile picture if available
                    if (isset($user['profile_picture']) && !empty($user['profile_picture'])) {
                        $_SESSION['user_profile_picture'] = $user['profile_picture'];
                    }

                    // Set remember me cookie if checked (30 days)
                    if ($rememberMe) {
                        $token = base64_encode($email);
                        setcookie('texol_remember', $token, time() + (30 * 24 * 60 * 60), ' ', '', false, true);
                    } else {
                        // Clear remember me cookie if not checked
                        if (isset($_COOKIE['texol_remember'])) {
                            setcookie('texol_remember', '', time() - 3600, ' ');
                        }
                    }

                    header('Location:  index');
                    exit;
                }
            }
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Texol - Login</title>
  <style>
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    body {
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(135deg, #0f172a, #1e293b);
      color: #0f172a;
    }

    .login-wrapper {
      width: 100%;
      max-width: 420px;
      padding: 32px 28px 30px;
      background: #ffffff;
      border-radius: 18px;
      box-shadow:
        0 18px 45px rgba(15, 23, 42, 0.28),
        0 0 0 1px rgba(148, 163, 184, 0.12);
    }

    .brand {
      text-align: center;
      margin-bottom: 24px;
    }

    .brand-logo {
      height: 40px;
      margin-bottom: 8px;
    }

    .brand-subtitle {
      margin-top: 2px;
      font-size: 13px;
      color: #6b7280;
    }
    .brand {
      text-align: center;
      margin-bottom: 24px;
    }

    .brand-logo {
      height: 40px;
      margin-bottom: 8px;
    }

    .brand-subtitle {
      margin-top: 2px;
      font-size: 13px;
      color: #6b7280;
    }

    .login-title {
      font-size: 18px;
      font-weight: 600;
      margin-bottom: 6px;
      color: #111827;
    }

    .login-description {
      font-size: 13px;
      color: #6b7280;
      margin-bottom: 18px;
    }

    .field {
      margin-bottom: 14px;
    }

    .field label {
      display: block;
      margin-bottom: 6px;
      font-size: 13px;
      font-weight: 500;
      color: #374151;
    }

    .field input {
      width: 100%;
      padding: 9px 11px;
      border-radius: 10px;
      border: 1px solid #e5e7eb;
      font-size: 14px;
      color: #111827;
      outline: none;
      transition: border-color 0.15s ease, box-shadow 0.15s ease, background 0.15s ease;
      background-color: #f9fafb;
    }

    .field input:focus {
      border-color: #4f46e5;
      box-shadow: 0 0 0 1px rgba(79, 70, 229, 0.3);
      background-color: #ffffff;
    }

    .login-actions {
      margin-top: 16px;
    }

    .btn-primary {
      width: 100%;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 10px 16px;
      border-radius: 999px;
      border: none;
      background: linear-gradient(135deg, #4f46e5, #6366f1);
      color: #ffffff;
      font-size: 14px;
      font-weight: 600;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      cursor: pointer;
      transition: transform 0.12s ease, box-shadow 0.12s ease, filter 0.12s ease;
      box-shadow: 0 12px 25px rgba(79, 70, 229, 0.4);
    }

    .btn-primary:hover {
      transform: translateY(-1px);
      filter: brightness(1.03);
      box-shadow: 0 16px 32px rgba(79, 70, 229, 0.5);
    }

    .btn-primary:active {
      transform: translateY(0);
      box-shadow: 0 8px 18px rgba(79, 70, 229, 0.4);
    }

    .helper-text {
      margin-top: 10px;
      font-size: 12px;
      color: #9ca3af;
      text-align: center;
    }

    .error-message {
      margin-bottom: 12px;
      padding: 8px 10px;
      border-radius: 8px;
      background-color: #fef2f2;
      color: #b91c1c;
      font-size: 13px;
      border: 1px solid #fecaca;
    }

    @media (max-width: 480px) {
      .login-wrapper {
        margin: 12px;
        padding: 26px 20px 24px;
      }

      .brand-name {
        font-size: 24px;
      }
    }
  </style>
  <link rel="icon" type="image/svg+xml" href="https://www.texolenergies.com/assets/Texol_icon-AiPT1Z13.png">
</head>
<body>
  <div class="login-wrapper">
    <div class="brand">
      <img
        src="https://www.texolenergies.com/assets/Logo-paGHQfRF.svg"
        alt="Texol Energies"
        class="brand-logo"
      />
      <div class="brand-subtitle">Secure access portal</div>
    </div>

    <h1 class="login-title">Sign in</h1>

    <?php if (!empty($error)) : ?>
      <div class="error-message">
        <?php echo htmlspecialchars($error, ENT_QUOTES, 'UTF-8'); ?>
      </div>
    <?php endif; ?>

    <form method="post" action=" login">
      <div class="field">
        <label for="email">Email</label>
        <input
          type="email"
          id="email"
          name="email"
          placeholder="Enter your email address"
          value="<?php echo htmlspecialchars($rememberEmail, ENT_QUOTES, 'UTF-8'); ?>"
          required
        />
      </div>

      <div class="field">
        <label for="password">Password</label>
        <input
          type="password"
          id="password"
          name="password"
          placeholder="••••••••"
          required
        />
      </div>
  <div style="text-align: right; margin-top: -8px; margin-bottom: 12px;">
    <a href="forgot_password" style="font-size: 13px; color: #0d6efd; text-decoration: none;">
      Forgot Password?
    </a>
  </div>
      <div class="field" style="margin-bottom: 16px;">
        <label style="display: flex; align-items: center; cursor: pointer; margin-bottom: 0;">
          <input
            type="checkbox"
            id="remember_me"
            name="remember_me"
            value="1"
            style="width: auto; margin-right: 8px; cursor: pointer;"
            <?php echo !empty($rememberEmail) ? 'checked' : ''; ?>
          />
          <span style="font-size: 13px; color: #374151;">Remember me</span>
        </label>
      </div>

      <div class="login-actions">
        <button type="submit" class="btn-primary">Login</button>
      </div>

      <div class="helper-text">
        Don't have an account? <a href="register" style="color: #0d6efd; text-decoration: none;">Create Account</a>
      </div>

    </form>
  </div>
</body>
</html>

