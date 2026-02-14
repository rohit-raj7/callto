import axios from 'axios';

const resolvedBase =
  typeof import.meta.env.VITE_API_BASE_URL === 'string' && import.meta.env.VITE_API_BASE_URL.length > 0
    ? import.meta.env.VITE_API_BASE_URL
    // : 'https://call-to.onrender.com/api';
    : 'http://localhost:3002/api';
const localFallbacks = [
  'http://localhost:3002/api',
  'http://127.0.0.1:3002/api'
];
const fallbackBases = [resolvedBase, ...localFallbacks.filter((b) => b !== resolvedBase)];
const api = axios.create({ baseURL: resolvedBase });
const isUsableToken = (token) => {
  const normalized = String(token || '').trim();
  return Boolean(normalized) && normalized !== 'undefined' && normalized !== 'null';
};

// Request interceptor to add Authorization header
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('adminToken');
    if (isUsableToken(token)) {
      config.headers.Authorization = `Bearer ${token}`;
    } else if (token) {
      localStorage.removeItem('adminToken');
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor to handle errors
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const config = error.config;
    const isNetworkError = error.code === 'ERR_NETWORK';
    const isNotFoundOutbox =
      error.response?.status === 404 && config && typeof config.url === 'string' && /\/notifications\/outbox/.test(config.url);
    if ((isNetworkError || isNotFoundOutbox) && config && !config.__retryWithFallback) {
      const baseBefore = config.baseURL || api.defaults.baseURL;
      const startIndex =
        fallbackBases.indexOf(baseBefore) !== -1 ? fallbackBases.indexOf(baseBefore) : fallbackBases.indexOf(api.defaults.baseURL);
      for (let i = startIndex + 1; i < fallbackBases.length; i++) {
        api.defaults.baseURL = fallbackBases[i];
        if (config.baseURL) delete config.baseURL;
        if (typeof config.url === 'string' && /^https?:\/\//i.test(config.url)) {
          try {
            const u = new URL(config.url);
            config.url = `${u.pathname}${u.search}${u.hash}`;
          } catch {
            void 0;
          }
        }
        config.__retryWithFallback = true;
        try {
          return await api.request(config);
        } catch (e) {
          console.warn('API fallback failed', e);
        }
      }
    }
    if (error.response?.status === 401) {
      localStorage.removeItem('adminToken');
      window.location.href = '/admin-no-all-call';
    }
    return Promise.reject(error);
  }
);

// User methods
export const getUsers = () => api.get('/users');
export const getUserById = (user_id) => api.get(`/users/${user_id}`);
export const updateUser = (user_id, payload) => api.put(`/users/${user_id}`, payload);
export const deleteUser = (user_id) => api.delete(`/users/${user_id}`);

// Listener methods
export const getListeners = () => api.get('/listeners');
export const getListenerById = (listener_id) => api.get(`/listeners/${listener_id}`);
export const updateListener = (listener_id, payload) => api.put(`/listeners/${listener_id}`, payload);
export const deleteListener = (listener_id) => api.delete(`/listeners/${listener_id}`);

// Admin methods
export const getAdminListeners = () => api.get('/admin/listeners');
export const getAppRatings = (params = {}) => api.get('/admin/app-ratings', { params });
export const deleteAppRatings = (ratingIds = []) =>
  api.delete('/admin/app-ratings', { data: { rating_ids: ratingIds } });
export const getContactMessages = (params = {}) => api.get('/admin/contact-messages', { params });
export const getDeleteRequests = (params = {}) => api.get('/admin/delete-requests', { params });
export const deleteDeleteRequest = (request_id) => api.delete(`/admin/delete-requests/${request_id}`);
export const updateListenerVerificationStatus = (listener_id, status, rejection_reason = null) => 
  api.put(`/admin/listeners/${listener_id}/verification-status`, { status, rejection_reason });
export const setListenerRates = (payload) => api.post('/admin/listener/set-rates', payload);
export const updateListenerRates = (listener_id, payload) =>
  api.put(`/admin/listener/update-rates/${listener_id}`, payload);
export const getRateConfig = () => api.get('/admin/rate-config');
export const updateRateConfig = (payload) => api.put('/admin/rate-config', payload);

// Chat Charge Config methods
export const getChatChargeConfig = () => api.get('/admin/chat-charge-config');
export const updateChatChargeConfig = (payload) => api.put('/admin/chat-charge-config', payload);
export const getOfferBannerConfig = () => api.get('/admin/offer-banner');
export const updateOfferBannerConfig = (payload) => api.put('/admin/offer-banner', payload);

export const getOutbox = (params = {}) => api.get('/notifications/outbox', { params });
export const updateOutbox = (id, payload) => api.put(`/notifications/outbox/${id}`, payload);
export const deleteOutbox = (id) => api.delete(`/notifications/outbox/${id}`);

// Recharge Pack methods
export const getRechargePacks = () => api.get('/recharge-packs/all');
export const createRechargePack = (payload) => api.post('/recharge-packs', payload);
export const updateRechargePack = (id, payload) => api.put(`/recharge-packs/${id}`, payload);
export const deleteRechargePack = (id) => api.delete(`/recharge-packs/${id}`);

// User Transactions (admin)
export const getUserTransactions = (user_id) => api.get(`/admin/users/${user_id}/transactions`);

export default api;
