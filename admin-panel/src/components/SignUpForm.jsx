import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ChevronRight, ChevronLeft, Check, Upload, X, Loader2 } from 'lucide-react';
import clsx from 'clsx';

const SignUpForm = ({ onComplete, onCancel }) => {
  const [currentStep, setCurrentStep] = useState(1);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formData, setFormData] = useState({
    // Step 1: Email & Password
    email: '',
    password: '',
    confirmPassword: '',
    
    // Step 2: Personal Info
    firstName: '',
    lastName: '',
    age: '',
    location: '',
    gender: '',
    
    // Step 3: Interests
    selectedInterests: [],
    
    // Step 4: Profile Photo
    profilePhoto: null,
    photoPreview: null,
  });

  const [errors, setErrors] = useState({});

  const totalSteps = 4;

  // Available interests by category
  const interestCategories = {
    Sports: ['Football', 'Basketball', 'Tennis', 'Swimming', 'Yoga', 'Hiking'],
    Music: ['Rock', 'Pop', 'Jazz', 'Classical', 'Hip Hop', 'Electronic'],
    Tech: ['Programming', 'AI/ML', 'Gaming', 'Robotics', 'Web Dev', 'Mobile Dev'],
    Arts: ['Painting', 'Photography', 'Dancing', 'Cooking', 'Writing', 'Theater'],
    Lifestyle: ['Travel', 'Reading', 'Movies', 'Coffee', 'Fashion', 'Fitness'],
  };

  // Validation functions
  const validateStep1 = () => {
    const newErrors = {};
    
    if (!formData.email) {
      newErrors.email = 'Email is required';
    } else if (!/\S+@\S+\.\S+/.test(formData.email)) {
      newErrors.email = 'Email is invalid';
    }
    
    if (!formData.password) {
      newErrors.password = 'Password is required';
    } else if (formData.password.length < 8) {
      newErrors.password = 'Password must be at least 8 characters';
    }
    
    if (formData.password !== formData.confirmPassword) {
      newErrors.confirmPassword = 'Passwords do not match';
    }
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const validateStep2 = () => {
    const newErrors = {};
    
    if (!formData.firstName) newErrors.firstName = 'First name is required';
    if (!formData.lastName) newErrors.lastName = 'Last name is required';
    if (!formData.age) {
      newErrors.age = 'Age is required';
    } else if (formData.age < 18 || formData.age > 100) {
      newErrors.age = 'Age must be between 18 and 100';
    }
    if (!formData.location) newErrors.location = 'Location is required';
    if (!formData.gender) newErrors.gender = 'Gender is required';
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const validateStep3 = () => {
    const newErrors = {};
    
    if (formData.selectedInterests.length === 0) {
      newErrors.interests = 'Please select at least one interest';
    }
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  // Handle input changes
  const handleChange = (field, value) => {
    setFormData(prev => ({ ...prev, [field]: value }));
    // Clear error for this field
    if (errors[field]) {
      setErrors(prev => ({ ...prev, [field]: undefined }));
    }
  };

  // Handle interest toggle
  const toggleInterest = (interest) => {
    setFormData(prev => ({
      ...prev,
      selectedInterests: prev.selectedInterests.includes(interest)
        ? prev.selectedInterests.filter(i => i !== interest)
        : prev.selectedInterests.length < 10
        ? [...prev.selectedInterests, interest]
        : prev.selectedInterests
    }));
    
    if (errors.interests) {
      setErrors(prev => ({ ...prev, interests: undefined }));
    }
  };

  // Handle photo upload
  const handlePhotoUpload = (e) => {
    const file = e.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setFormData(prev => ({
          ...prev,
          profilePhoto: file,
          photoPreview: reader.result
        }));
      };
      reader.readAsDataURL(file);
    }
  };

  // Remove photo
  const removePhoto = () => {
    setFormData(prev => ({
      ...prev,
      profilePhoto: null,
      photoPreview: null
    }));
  };

  // Navigation
  const goToNextStep = () => {
    let isValid = true;
    
    if (currentStep === 1) isValid = validateStep1();
    if (currentStep === 2) isValid = validateStep2();
    if (currentStep === 3) isValid = validateStep3();
    
    if (isValid && currentStep < totalSteps) {
      setCurrentStep(prev => prev + 1);
    }
  };

  const goToPrevStep = () => {
    if (currentStep > 1) {
      setCurrentStep(prev => prev - 1);
      setErrors({});
    }
  };

  // Submit form
  const handleSubmit = async () => {
    setIsSubmitting(true);
    
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    if (onComplete) {
      onComplete(formData);
    }
    
    setIsSubmitting(false);
  };

  // Progress indicator
  const ProgressBar = () => (
    <div className="mb-8">
      <div className="flex justify-between items-center mb-2">
        {[1, 2, 3, 4].map((step) => (
          <div key={step} className="flex items-center flex-1">
            <div
              className={clsx(
                'w-10 h-10 rounded-full flex items-center justify-center font-semibold transition-all',
                step < currentStep
                  ? 'bg-green-500 text-white'
                  : step === currentStep
                  ? 'bg-indigo-600 text-white'
                  : 'bg-gray-200 dark:bg-gray-700 text-gray-500'
              )}
            >
              {step < currentStep ? <Check className="w-5 h-5" /> : step}
            </div>
            {step < 4 && (
              <div
                className={clsx(
                  'flex-1 h-1 mx-2 transition-all',
                  step < currentStep
                    ? 'bg-green-500'
                    : 'bg-gray-200 dark:bg-gray-700'
                )}
              />
            )}
          </div>
        ))}
      </div>
      <div className="flex justify-between text-xs text-gray-600 dark:text-gray-400 mt-2">
        <span>Account</span>
        <span>Personal</span>
        <span>Interests</span>
        <span>Photo</span>
      </div>
    </div>
  );

  // Step content
  const renderStepContent = () => {
    switch (currentStep) {
      case 1:
        return (
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="space-y-4"
          >
            <h2 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">
              Create Your Account
            </h2>
            <p className="text-gray-600 dark:text-gray-400 mb-6">
              Let's start with your email and password
            </p>

            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                Email
              </label>
              <input
                type="email"
                value={formData.email}
                onChange={(e) => handleChange('email', e.target.value)}
                className={clsx(
                  'w-full px-4 py-3 rounded-lg border transition-colors',
                  errors.email
                    ? 'border-red-500 focus:ring-red-500'
                    : 'border-gray-300 dark:border-gray-600 focus:ring-indigo-500',
                  'bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2'
                )}
                placeholder="you@example.com"
              />
              {errors.email && (
                <p className="text-red-500 text-sm mt-1">{errors.email}</p>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                Password
              </label>
              <input
                type="password"
                value={formData.password}
                onChange={(e) => handleChange('password', e.target.value)}
                className={clsx(
                  'w-full px-4 py-3 rounded-lg border transition-colors',
                  errors.password
                    ? 'border-red-500 focus:ring-red-500'
                    : 'border-gray-300 dark:border-gray-600 focus:ring-indigo-500',
                  'bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2'
                )}
                placeholder="At least 8 characters"
              />
              {errors.password && (
                <p className="text-red-500 text-sm mt-1">{errors.password}</p>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                Confirm Password
              </label>
              <input
                type="password"
                value={formData.confirmPassword}
                onChange={(e) => handleChange('confirmPassword', e.target.value)}
                className={clsx(
                  'w-full px-4 py-3 rounded-lg border transition-colors',
                  errors.confirmPassword
                    ? 'border-red-500 focus:ring-red-500'
                    : 'border-gray-300 dark:border-gray-600 focus:ring-indigo-500',
                  'bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2'
                )}
                placeholder="Confirm your password"
              />
              {errors.confirmPassword && (
                <p className="text-red-500 text-sm mt-1">{errors.confirmPassword}</p>
              )}
            </div>
          </motion.div>
        );

      case 2:
        return (
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="space-y-4"
          >
            <h2 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">
              Tell Us About Yourself
            </h2>
            <p className="text-gray-600 dark:text-gray-400 mb-6">
              Help others get to know you better
            </p>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  First Name
                </label>
                <input
                  type="text"
                  value={formData.firstName}
                  onChange={(e) => handleChange('firstName', e.target.value)}
                  className={clsx(
                    'w-full px-4 py-3 rounded-lg border transition-colors',
                    errors.firstName
                      ? 'border-red-500 focus:ring-red-500'
                      : 'border-gray-300 dark:border-gray-600 focus:ring-indigo-500',
                    'bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2'
                  )}
                />
                {errors.firstName && (
                  <p className="text-red-500 text-sm mt-1">{errors.firstName}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Last Name
                </label>
                <input
                  type="text"
                  value={formData.lastName}
                  onChange={(e) => handleChange('lastName', e.target.value)}
                  className={clsx(
                    'w-full px-4 py-3 rounded-lg border transition-colors',
                    errors.lastName
                      ? 'border-red-500 focus:ring-red-500'
                      : 'border-gray-300 dark:border-gray-600 focus:ring-indigo-500',
                    'bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2'
                  )}
                />
                {errors.lastName && (
                  <p className="text-red-500 text-sm mt-1">{errors.lastName}</p>
                )}
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Age
                </label>
                <input
                  type="number"
                  value={formData.age}
                  onChange={(e) => handleChange('age', parseInt(e.target.value))}
                  className={clsx(
                    'w-full px-4 py-3 rounded-lg border transition-colors',
                    errors.age
                      ? 'border-red-500 focus:ring-red-500'
                      : 'border-gray-300 dark:border-gray-600 focus:ring-indigo-500',
                    'bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2'
                  )}
                  min="18"
                  max="100"
                />
                {errors.age && (
                  <p className="text-red-500 text-sm mt-1">{errors.age}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Gender
                </label>
                <select
                  value={formData.gender}
                  onChange={(e) => handleChange('gender', e.target.value)}
                  className={clsx(
                    'w-full px-4 py-3 rounded-lg border transition-colors',
                    errors.gender
                      ? 'border-red-500 focus:ring-red-500'
                      : 'border-gray-300 dark:border-gray-600 focus:ring-indigo-500',
                    'bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2'
                  )}
                >
                  <option value="">Select...</option>
                  <option value="male">Male</option>
                  <option value="female">Female</option>
                  <option value="non-binary">Non-binary</option>
                  <option value="prefer-not-to-say">Prefer not to say</option>
                </select>
                {errors.gender && (
                  <p className="text-red-500 text-sm mt-1">{errors.gender}</p>
                )}
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                Location
              </label>
              <input
                type="text"
                value={formData.location}
                onChange={(e) => handleChange('location', e.target.value)}
                className={clsx(
                  'w-full px-4 py-3 rounded-lg border transition-colors',
                  errors.location
                    ? 'border-red-500 focus:ring-red-500'
                    : 'border-gray-300 dark:border-gray-600 focus:ring-indigo-500',
                  'bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2'
                )}
                placeholder="City, Country"
              />
              {errors.location && (
                <p className="text-red-500 text-sm mt-1">{errors.location}</p>
              )}
            </div>
          </motion.div>
        );

      case 3:
        return (
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="space-y-4"
          >
            <h2 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">
              Choose Your Interests
            </h2>
            <p className="text-gray-600 dark:text-gray-400 mb-4">
              Select up to 10 interests (Selected: {formData.selectedInterests.length}/10)
            </p>

            {errors.interests && (
              <p className="text-red-500 text-sm mb-4">{errors.interests}</p>
            )}

            <div className="space-y-6">
              {Object.entries(interestCategories).map(([category, interests]) => (
                <div key={category}>
                  <h3 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">
                    {category}
                  </h3>
                  <div className="flex flex-wrap gap-2">
                    {interests.map((interest) => {
                      const isSelected = formData.selectedInterests.includes(interest);
                      const isDisabled = !isSelected && formData.selectedInterests.length >= 10;

                      return (
                        <motion.button
                          key={interest}
                          whileHover={{ scale: isDisabled ? 1 : 1.05 }}
                          whileTap={{ scale: isDisabled ? 1 : 0.95 }}
                          onClick={() => !isDisabled && toggleInterest(interest)}
                          disabled={isDisabled}
                          className={clsx(
                            'px-4 py-2 rounded-full font-medium transition-all',
                            isSelected
                              ? 'bg-gradient-to-r from-indigo-600 to-purple-600 text-white'
                              : isDisabled
                              ? 'bg-gray-100 dark:bg-gray-800 text-gray-400 cursor-not-allowed'
                              : 'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600'
                          )}
                        >
                          {interest}
                        </motion.button>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          </motion.div>
        );

      case 4:
        return (
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="space-y-4"
          >
            <h2 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">
              Add Your Photo
            </h2>
            <p className="text-gray-600 dark:text-gray-400 mb-6">
              Upload a profile picture (optional)
            </p>

            <div className="flex flex-col items-center">
              {formData.photoPreview ? (
                <div className="relative">
                  <img
                    src={formData.photoPreview}
                    alt="Profile preview"
                    className="w-40 h-40 rounded-full object-cover ring-4 ring-indigo-100 dark:ring-indigo-900"
                  />
                  <button
                    onClick={removePhoto}
                    className="absolute top-0 right-0 p-2 bg-red-500 text-white rounded-full hover:bg-red-600 transition-colors"
                  >
                    <X className="w-4 h-4" />
                  </button>
                </div>
              ) : (
                <label className="w-40 h-40 flex flex-col items-center justify-center border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-full cursor-pointer hover:border-indigo-500 dark:hover:border-indigo-400 transition-colors">
                  <Upload className="w-10 h-10 text-gray-400 mb-2" />
                  <span className="text-sm text-gray-600 dark:text-gray-400">Upload Photo</span>
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handlePhotoUpload}
                    className="hidden"
                  />
                </label>
              )}

              <p className="text-sm text-gray-500 dark:text-gray-400 mt-4 text-center">
                Choose a clear photo of yourself
                <br />
                (JPG, PNG - Max 5MB)
              </p>
            </div>
          </motion.div>
        );

      default:
        return null;
    }
  };

  return (
    <div className="w-full max-w-2xl mx-auto bg-white dark:bg-gray-800 rounded-2xl shadow-xl p-8">
      <ProgressBar />

      <AnimatePresence mode="wait">
        {renderStepContent()}
      </AnimatePresence>

      {/* Navigation Buttons */}
      <div className="flex justify-between mt-8 pt-6 border-t border-gray-200 dark:border-gray-700">
        <div>
          {currentStep > 1 && (
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={goToPrevStep}
              className="flex items-center space-x-2 px-6 py-3 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded-lg font-medium hover:bg-gray-200 dark:hover:bg-gray-600 transition-colors"
            >
              <ChevronLeft className="w-5 h-5" />
              <span>Back</span>
            </motion.button>
          )}
          {currentStep === 1 && onCancel && (
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={onCancel}
              className="px-6 py-3 text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition-colors"
            >
              Cancel
            </motion.button>
          )}
        </div>

        <div>
          {currentStep < totalSteps ? (
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={goToNextStep}
              className="flex items-center space-x-2 px-6 py-3 bg-gradient-to-r from-indigo-600 to-purple-600 text-white rounded-lg font-medium hover:shadow-lg transition-all"
            >
              <span>Next</span>
              <ChevronRight className="w-5 h-5" />
            </motion.button>
          ) : (
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={handleSubmit}
              disabled={isSubmitting}
              className={clsx(
                'flex items-center space-x-2 px-8 py-3 rounded-lg font-medium transition-all',
                isSubmitting
                  ? 'bg-gray-300 dark:bg-gray-600 text-gray-500 cursor-not-allowed'
                  : 'bg-gradient-to-r from-green-600 to-emerald-600 text-white hover:shadow-lg'
              )}
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="w-5 h-5 animate-spin" />
                  <span>Creating Account...</span>
                </>
              ) : (
                <>
                  <Check className="w-5 h-5" />
                  <span>Complete Sign Up</span>
                </>
              )}
            </motion.button>
          )}
        </div>
      </div>
    </div>
  );
};

export default SignUpForm;
