import axios from 'axios';

async function sendPushFCM(token, title, body, data = {}) {
  const key = process.env.FCM_SERVER_KEY;
  if (!key || !token) return { success: false };
  const payload = {
    to: token,
    notification: { title, body },
    data,
    priority: 'high'
  };
  const res = await axios.post('https://fcm.googleapis.com/fcm/send', payload, {
    headers: {
      Authorization: `key=${key}`,
      'Content-Type': 'application/json'
    },
    timeout: 10000
  });
  return { success: res.status >= 200 && res.status < 300 };
}

export { sendPushFCM };

