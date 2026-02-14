import React from 'react';
import { useLocation, Link } from 'react-router-dom';
import { ChevronRight, Home } from 'lucide-react';

const Breadcrumb = () => {
  const location = useLocation();
  const pathnames = location.pathname.split('/').filter((x) => x);

  const breadcrumbNameMap = {
    'admin': 'Admin',
    'dashboard': 'Dashboard',
    'users': 'Users',
    'listeners': 'Listeners',
    'user-contacts': 'User Contacts',
    'send-notification': 'Send Notification',
    'contact-messages': 'Contact Messages',
    'delete-requests': 'Delete Requests',
    'offer-banner': 'Offer Banner',
  };

  return (
    <nav className="flex items-center space-x-2 text-sm text-gray-600 dark:text-gray-400 mb-6">
      <Link 
        to="/admin-no-all-call/dashboard" 
        className="hover:text-blue-600 dark:hover:text-blue-400 transition-colors"
      >
        <Home className="w-4 h-4" />
      </Link>
      {pathnames.map((value, index) => {
        const to = `/${pathnames.slice(0, index + 1).join('/')}`;
        const isLast = index === pathnames.length - 1;
        const label = breadcrumbNameMap[value] || value;

        return (
          <React.Fragment key={to}>
            <ChevronRight className="w-4 h-4" />
            {isLast ? (
              <span className="font-medium text-gray-900 dark:text-white">{label}</span>
            ) : (
              <Link 
                to={to} 
                className="hover:text-blue-600 dark:hover:text-blue-400 transition-colors"
              >
                {label}
              </Link>
            )}
          </React.Fragment>
        );
      })}
    </nav>
  );
};

export default Breadcrumb;
