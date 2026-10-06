<?php
require_once __DIR__ . '/../auth.php';

header('Content-Type: application/json; charset=utf-8');

$payload = json_decode(file_get_contents('php://input'), true);
if (!is_array($payload)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Invalid JSON input']);
    exit;
}

$requisitionId = trim((string) ($payload['requisition_id'] ?? ''));
$action = trim((string) ($payload['action'] ?? 'created'));
$allowedActions = ['created', 'updated', 'approved', 'rejected'];
if ($requisitionId === '' || !in_array($action, $allowedActions, true)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Requisition ID and a supported event are required']);
    exit;
}

if (!defined('SUPABASE_URL') || !defined('SUPABASE_SERVICE_ROLE_KEY')) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Supabase service configuration is unavailable']);
    exit;
}

function requisition_mail_get(string $resource, array $params = []): array
{
    $path = $resource;
    if ($params) {
        $path .= '?' . http_build_query($params);
    }
    $result = auth_supabase('GET', $path);
    return ($result['code'] >= 200 && $result['code'] < 300 && is_array($result['data'])) ? $result['data'] : [];
}

$requisitionRows = requisition_mail_get('requisitions', [
    'select' => 'id,requisition_number,requested_by,department,required_date,description,status,shared_with,items:requisition_items(id,item:items(id,name,unit),quantity,unit_price)',
    'id' => 'eq.' . $requisitionId,
    'limit' => 1,
]);
$requisition = $requisitionRows[0] ?? null;
if (!$requisition) {
    http_response_code(404);
    echo json_encode(['status' => 'error', 'message' => 'Requisition not found']);
    exit;
}

$requesterId = (string) ($requisition['requested_by'] ?? '');
$sharedValue = $requisition['shared_with'] ?? '';
if (is_array($sharedValue)) {
    $sharedIds = $sharedValue;
} else {
    $decodedShared = json_decode((string) $sharedValue, true);
    $sharedIds = is_array($decodedShared) ? $decodedShared : explode(',', (string) $sharedValue);
}
$sharedIds = array_values(array_unique(array_filter(array_map(
    static fn($id): string => trim((string) $id),
    $sharedIds
))));
$sharedIds = array_values(array_filter($sharedIds, static fn(string $id): bool => preg_match(
    '/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i',
    $id
) === 1));
$currentUserId = (string) ($_SESSION['user_id'] ?? '');
$isRequester = $requesterId !== '' && hash_equals($requesterId, $currentUserId);
$isShared = $currentUserId !== '' && in_array($currentUserId, $sharedIds, true);
if (!is_admin() && !$isRequester && !$isShared) {
    http_response_code(403);
    echo json_encode(['status' => 'error', 'message' => 'You are not allowed to send this requisition notification']);
    exit;
}

$requesterRows = $requesterId === '' ? [] : requisition_mail_get('users', [
    'select' => 'id,email,full_name',
    'id' => 'eq.' . $requesterId,
    'limit' => 1,
]);
$requester = $requesterRows[0] ?? [];
$requisition['requester_email'] = $requester['email'] ?? '';
$requisition['requester_name'] = $requester['full_name'] ?? $requester['email'] ?? 'Unknown';

$templateFiles = [
    'created' => 'created.php',
    'updated' => 'updated.php',
    'approved' => 'approved.php',
    'rejected' => 'rejected.php',
];
$template = require __DIR__ . '/../MailTemplates/requisitions/' . $templateFiles[$action];
$rpc = auth_supabase('POST', 'rpc/get_notification_recipients', [
    'p_event' => $template['event_key'],
    'p_department' => $requisition['department'] ?? '',
    'p_requester_id' => $requesterId !== '' ? $requesterId : null,
]);

$recipients = [];
if ($rpc['code'] === 200 && is_array($rpc['data'])) {
    foreach ($rpc['data'] as $recipient) {
        $email = $recipient['email'] ?? '';
        if (filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $recipients[] = $email;
        }
    }
}

$managementRows = requisition_mail_get('users', [
    'select' => 'email',
    'role' => 'ilike.management',
    'status' => 'eq.active',
]);
foreach ($managementRows as $manager) {
    if (filter_var($manager['email'] ?? '', FILTER_VALIDATE_EMAIL)) {
        $recipients[] = $manager['email'];
    }
}

if ($action === 'created') {
    $adminRows = requisition_mail_get('users', [
        'select' => 'email',
        'role' => 'ilike.admin',
        'status' => 'eq.active',
    ]);
    foreach ($adminRows as $admin) {
        if (filter_var($admin['email'] ?? '', FILTER_VALIDATE_EMAIL)) {
            $recipients[] = $admin['email'];
        }
    }

    $department = trim((string) ($requisition['department'] ?? ''));
    if ($department !== '') {
        $hodRows = requisition_mail_get('users', [
            'select' => 'email,department',
            'role' => 'ilike.hod',
            'status' => 'eq.active',
        ]);
        foreach ($hodRows as $hod) {
            if (strcasecmp(trim((string) ($hod['department'] ?? '')), $department) === 0
                && filter_var($hod['email'] ?? '', FILTER_VALIDATE_EMAIL)) {
                $recipients[] = $hod['email'];
            }
        }
    }

    if ($sharedIds) {
        $sharedQuery = requisition_mail_get('users', [
            'select' => 'email',
            'id' => 'in.(' . implode(',', $sharedIds) . ')',
        ]);
        foreach ($sharedQuery as $sharedUser) {
            if (filter_var($sharedUser['email'] ?? '', FILTER_VALIDATE_EMAIL)) {
                $recipients[] = $sharedUser['email'];
            }
        }
    }
}

if (filter_var($requisition['requester_email'], FILTER_VALIDATE_EMAIL)) {
    $recipients[] = $requisition['requester_email'];
}
$recipientMap = [];
foreach ($recipients as $email) {
    $email = trim((string) $email);
    if (filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $recipientMap[strtolower($email)] = $email;
    }
}
$recipients = array_values($recipientMap);
if (!$recipients) {
    echo json_encode(['status' => 'success', 'message' => 'No recipients configured for this event']);
    exit;
}

require_once __DIR__ . '/../MailTemplates/requisitions/render.php';
try {
    $email = render_requisition_email($action, $requisition, ['added_by' => $payload['added_by'] ?? 'Unknown User']);
} catch (Throwable $error) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Could not render requisition email']);
    exit;
}

$sendmail = curl_init('http://support.texolenergies.com/sendmail.php');
curl_setopt_array($sendmail, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POST => true,
    CURLOPT_CONNECTTIMEOUT => 5,
    CURLOPT_TIMEOUT => 25,
    CURLOPT_USERAGENT => 'Mozilla/5.0 (compatible; THI-Notifier/1.0)',
    CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'Accept: application/json'],
    CURLOPT_POSTFIELDS => json_encode([
        'to' => implode(',', $recipients),
        'subject' => $email['subject'],
        'body' => $email['body'],
    ]),
]);
$response = curl_exec($sendmail);
$httpCode = (int) curl_getinfo($sendmail, CURLINFO_HTTP_CODE);
$curlError = curl_error($sendmail);
curl_close($sendmail);

$result = is_string($response) ? json_decode($response, true) : null;
if ($response === false || $httpCode < 200 || $httpCode >= 300 || ($result['status'] ?? '') !== 'success') {
    $detail = $curlError ?: ($result['message'] ?? '');
    if ($detail === '' && is_string($response)) {
        $detail = trim(preg_replace('/\s+/', ' ', strip_tags($response)));
    }
    $detail = $detail !== '' ? substr($detail, 0, 300) : 'Unexpected sendmail response';
    error_log('Requisition sendmail upstream failure: HTTP ' . $httpCode . '; ' . $detail);
    http_response_code(502);
    echo json_encode([
        'status' => 'error',
        'message' => 'The sendmail service failed to send the requisition notification',
        'sendmail_http_status' => $httpCode,
        'detail' => $detail,
    ]);
    exit;
}

echo json_encode(['status' => 'success', 'message' => 'Requisition notification sent']);
