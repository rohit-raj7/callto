import React from 'react';
import { AlertTriangle, RefreshCw } from 'lucide-react';

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null, errorInfo: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true };
  }

  componentDidCatch(error, errorInfo) {
    console.error('Error caught by boundary:', error, errorInfo);
    this.setState({
      error,
      errorInfo
    });
  }

  handleRetry = () => {
    this.setState({ hasError: false, error: null, errorInfo: null });
  };

  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-gray-50 dark:bg-gray-900 flex items-center justify-center p-4">
          <div className="max-w-md w-full bg-white dark:bg-gray-800 rounded-lg shadow-xl p-8">
            <div className="flex items-center justify-center w-16 h-16 mx-auto mb-4 bg-red-100 dark:bg-red-900/30 rounded-full">
              <AlertTriangle className="w-8 h-8 text-red-600 dark:text-red-400" />
            </div>
            <h2 className="text-2xl font-bold text-center text-gray-900 dark:text-white mb-2">
              Oops! Something went wrong
            </h2>
            <p className="text-center text-gray-600 dark:text-gray-400 mb-6">
              The application encountered an unexpected error. Please try again.
            </p>
            
            {this.state.error && (
              <details className="mb-6">
                <summary className="cursor-pointer text-sm text-gray-600 dark:text-gray-400 mb-2">
                  Error Details (for developers)
                </summary>
                <div className="bg-gray-100 dark:bg-gray-700 rounded p-4 text-xs font-mono overflow-auto max-h-48">
                  <p className="text-red-600 dark:text-red-400 mb-2">
                    {this.state.error.toString()}
                  </p>
                  <pre className="text-gray-700 dark:text-gray-300 whitespace-pre-wrap">
                    {this.state.errorInfo?.componentStack}
                  </pre>
                </div>
              </details>
            )}

            <div className="flex space-x-3">
              <button
                onClick={this.handleRetry}
                className="flex-1 flex items-center justify-center space-x-2 px-4 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-semibold transition-colors"
              >
                <RefreshCw className="w-5 h-5" />
                <span>Try Again</span>
              </button>
              <button
                onClick={() => window.location.href = '/admin-no-all-call/dashboard'}
                className="flex-1 px-4 py-3 bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-900 dark:text-white rounded-lg font-semibold transition-colors"
              >
                Go Home
              </button>
            </div>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}

export default ErrorBoundary;
