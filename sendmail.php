<?php
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

require __DIR__ . '/PHPMailer/src/Exception.php';
require __DIR__ . '/PHPMailer/src/PHPMailer.php';
require __DIR__ . '/PHPMailer/src/SMTP.php';

// ---- CORS: allow everything ----
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: *');
header('Access-Control-Max-Age: 86400');
header('Content-Type: application/json; charset=utf-8');

// Preflight
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

ini_set('display_errors', 0);
error_reporting(E_ALL);

// ---- Input: JSON body, form POST, or query string ----
$input = $_REQUEST;
$raw = file_get_contents('php://input');
if ($raw) {
    $json = json_decode($raw, true);
    if (is_array($json)) $input = array_merge($input, $json);
}

$to_email      = $input['to'] ?? '';
$cc_emails     = $input['cc'] ?? '';
$bcc_emails    = $input['bcc'] ?? '';
$reply_to      = $input['reply_to'] ?? '';
$email_subject = $input['subject'] ?? '';
$email_body    = $input['body'] ?? 'This is a notification email.';

if (!$to_email || !$email_subject) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Missing to or subject']);
    exit;
}

function addList($list, $fn) {
    if (!is_array($list)) $list = explode(',', (string)$list);
    foreach ($list as $e) {
        $e = trim($e);
        if ($e !== '') $fn($e);
    }
}

$mail = new PHPMailer(true);

try {
    $mail->isSMTP();
    $mail->Host       = 'mail.texolenergies.com';
    $mail->SMTPAuth   = true;
    $mail->Username   = 'support@texolenergies.com';
    $mail->Password   = 'realziro@1997';
    $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
    $mail->Port       = 587;
    $mail->CharSet    = 'UTF-8';
    $mail->SMTPDebug  = 0;

    $mail->setFrom('support@texolenergies.com', 'THI Support');

    addList($to_email,   fn($e) => $mail->addAddress($e));
    addList($cc_emails,  fn($e) => $mail->addCC($e));
    addList($bcc_emails, fn($e) => $mail->addBCC($e));
    addList($reply_to,   fn($e) => $mail->addReplyTo($e));

    $mail->isHTML(true);
    $mail->Subject = $email_subject;
    $mail->Body    = $email_body;
    $mail->AltBody = strip_tags($email_body);

    $mail->send();

    echo json_encode(['status' => 'success', 'message' => 'Email sent successfully']);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => $mail->ErrorInfo]);
}
