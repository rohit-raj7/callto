import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import LandingPage from './pages/LandingPage';
import FAQs from './pages/FAQs';
import PrivacyPolicy from './pages/PrivacyPolicy';
import TermsOfService from './pages/TermsOfService';
import CookiePolicy from './pages/CookiePolicy';
import AdminLogin from './pages/ControlPanel';
import AdminDashboard from './pages/AdminDashboard';
import UsersManagement from './pages/UsersManagement';
import UserContactInfo from './pages/UserContactInfo';
import ContactMessages from './pages/ContactMessages';
import DeleteRequests from './pages/DeleteRequests';
import AppRatings from './pages/AppRatings';
import ListenersManagement from './pages/ListenersManagement';
import ListenerDetails from './pages/ListenerDetails';
import ListenerProfile from './pages/ListenerProfile';
import ListenerRateSettings from './pages/ListenerRateSettings';
import CallRateConfig from './pages/CallRateConfig';
import ChatChargeConfig from './pages/ChatChargeConfig';
import OfferBannerConfig from './pages/OfferBannerConfig';
import SendNotification from './pages/SendNotification';
import RechargePacks from './pages/RechargePacks';
import PrivateRoute from './components/PrivateRoute';
import Layout from './components/Layout';
import ErrorBoundary from './components/ErrorBoundary';
import { ThemeProvider } from './contexts/ThemeContext';
import { NotificationProvider } from './contexts/NotificationContext';
import { KeyboardShortcutProvider } from './contexts/KeyboardShortcutContext';


function App() {
  return (
    <ErrorBoundary>
      <NotificationProvider>
        <KeyboardShortcutProvider>
          <Router>
            <Routes>
              {/* Public Routes (no theme provider) */}
              <Route path="/" element={<LandingPage />} />
              <Route path="/faqs" element={<FAQs />} />
              <Route path="/privacy-policy" element={<PrivacyPolicy />} />
              <Route path="/terms-of-service" element={<TermsOfService />} />
              <Route path="/cookie-policy" element={<CookiePolicy />} />

              {/* Admin Routes (with theme provider) */}
              <Route path="/admin-no-all-call" element={
                <ThemeProvider>
                  <AdminLogin />
                </ThemeProvider>
              } />
              <Route path="/admin-no-all-call/dashboard" element={
                <ThemeProvider>
                  <PrivateRoute>
                    <Layout>
                      <AdminDashboard />
                    </Layout>
                  </PrivateRoute>
                </ThemeProvider>
              } />
              <Route path="/admin-no-all-call/users" element={
                <ThemeProvider>
                  <PrivateRoute>
                    <Layout>
                      <UsersManagement />
                    </Layout>
                  </PrivateRoute>
                </ThemeProvider>
              } />
              <Route path="/admin-no-all-call/user-contacts" element={
                <ThemeProvider>
                  <PrivateRoute>
                    <Layout>
                      <UserContactInfo />
                    </Layout>
                  </PrivateRoute>
                </ThemeProvider>
              } />
              <Route path="/admin-no-all-call/listeners" element={
                <ThemeProvider>
                  <PrivateRoute>
                    <Layout>
                      <ListenersManagement />
                    </Layout>
                  </PrivateRoute>
                </ThemeProvider>
              } />
              <Route path="/admin-no-all-call/listener-rates" element={
                <ThemeProvider>
                  <PrivateRoute>
                    <Layout>
                      <ListenerRateSettings />
                    </Layout>
                  </PrivateRoute>
                </ThemeProvider>
              } />
              <Route path="/admin-no-all-call/call-rate-config" element={
                <ThemeProvider>
                  <PrivateRoute>
                    <Layout>
                      <CallRateConfig />
                    </Layout>
                  </PrivateRoute>
                </ThemeProvider>
              } />
              <Route path="/admin-no-all-call/chat-charge-config" element={
                <ThemeProvider>
                  <PrivateRoute>
                    <Layout>
                      <ChatChargeConfig />
                    </Layout>
                  </PrivateRoute>
                </ThemeProvider>
              } />
              <Route path="/admin-no-all-call/recharge-packs" element={
                <ThemeProvider>
                  <PrivateRoute>
                    <Layout>
                      <RechargePacks />
                    </Layout>
                  </PrivateRoute>
                </ThemeProvider>
              } />
              <Route path="/admin-no-all-call/offer-banner" element={
                <ThemeProvider>
                  <PrivateRoute>
                    <Layout>
                      <OfferBannerConfig />
                    </Layout>
                  </PrivateRoute>
                </ThemeProvider>
              } />
              <Route path="/admin-no-all-call/listeners/:listener_id" element={
                <ThemeProvider>
                  <PrivateRoute>
                    <Layout>
                      <ListenerDetails />
                    </Layout>
                  </PrivateRoute>
                </ThemeProvider>
              } />
              <Route path="/admin-no-all-call/send-notification" element={
                <ThemeProvider>
                  <PrivateRoute>
                    <Layout>
                      <SendNotification />
                    </Layout>
                  </PrivateRoute>
                </ThemeProvider>
              } />
              <Route path="/admin-no-all-call/contact-messages" element={
                <ThemeProvider>
                  <PrivateRoute>
                    <Layout>
                      <ContactMessages />
                    </Layout>
                  </PrivateRoute>
                </ThemeProvider>
              } />
              <Route path="/admin-no-all-call/app-ratings" element={
                <ThemeProvider>
                  <PrivateRoute>
                    <Layout>
                      <AppRatings />
                    </Layout>
                  </PrivateRoute>
                </ThemeProvider>
              } />
              <Route path="/admin-no-all-call/delete-requests" element={
                <ThemeProvider>
                  <PrivateRoute>
                    <Layout>
                      <DeleteRequests />
                    </Layout>
                  </PrivateRoute>
                </ThemeProvider>
              } />
            </Routes>
          </Router>
        </KeyboardShortcutProvider>
      </NotificationProvider>
    </ErrorBoundary>
  );
}

export default App;
