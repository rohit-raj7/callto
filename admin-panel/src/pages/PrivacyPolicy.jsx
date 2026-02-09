import React from 'react';

const PrivacyPolicy = () => {
  return (
    <div className="min-h-screen bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100">
      <div className="max-w-4xl mx-auto px-6 py-12">
        <h1 className="text-3xl font-bold mb-6">Privacy Policy</h1>
        <p className="text-gray-700 dark:text-gray-300 mb-4">
          This Privacy Policy explains how CallTo collects, uses, and protects your
          information when you use our services.
        </p>
        <div className="space-y-4 text-gray-700 dark:text-gray-300">
          <p>
            We collect only the data necessary to provide and improve our services,
            including account information and usage data. We do not sell personal data.
          </p>
          <p>
            We use industry-standard security measures to protect your data. However,
            no method of transmission or storage is completely secure.
          </p>
          <p>
            By using CallTo, you agree to the practices described in this policy. If
            you have any questions, please contact support.
          </p>
        </div>
      </div>
    </div>
  );
};

export default PrivacyPolicy;
