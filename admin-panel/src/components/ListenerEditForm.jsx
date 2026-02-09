import React, { useState } from 'react';

const ListenerEditForm = ({ listener, onSave, onClose }) => {
  const [formData, setFormData] = useState({
    professional_name: listener.professional_name || '',
    age: listener.age || '',
    specialties: listener.specialties?.join(', ') || '',
    languages: listener.languages?.join(', ') || '',
    rate_per_minute: listener.rate_per_minute || '',
    experience_years: listener.experience_years || '',
    education: listener.education || '',
    certifications: listener.certifications || '',
    avatar_url: listener.avatar_url || '',
  });

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    const normalizedData = {
      ...formData,
      specialties: formData.specialties.split(',').map(s => s.trim()).filter(s => s),
      languages: formData.languages.split(',').map(l => l.trim()).filter(l => l),
      age: parseInt(formData.age),
      rate_per_minute: parseFloat(formData.rate_per_minute),
      experience_years: parseInt(formData.experience_years),
    };
    onSave({ ...listener, ...normalizedData });
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white p-6 rounded-lg shadow-lg max-w-lg w-full max-h-screen overflow-y-auto">
        <h2 className="text-xl font-bold mb-4">Edit Listener</h2>
        <form onSubmit={handleSubmit} className="space-y-4">
          <label className="block">
            Professional Name:
            <input
              type="text"
              name="professional_name"
              value={formData.professional_name}
              onChange={handleChange}
              required
              className="w-full p-2 border border-gray-300 rounded mt-1"
            />
          </label>
          <label className="block">
            Age:
            <input
              type="number"
              name="age"
              value={formData.age}
              onChange={handleChange}
              required
              className="w-full p-2 border border-gray-300 rounded mt-1"
            />
          </label>
          <label className="block">
            Specialties (comma-separated):
            <input
              type="text"
              name="specialties"
              value={formData.specialties}
              onChange={handleChange}
              className="w-full p-2 border border-gray-300 rounded mt-1"
            />
          </label>
          <label className="block">
            Languages (comma-separated):
            <input
              type="text"
              name="languages"
              value={formData.languages}
              onChange={handleChange}
              className="w-full p-2 border border-gray-300 rounded mt-1"
            />
          </label>
          <label className="block">
            Rate per Minute:
            <input
              type="number"
              step="0.01"
              name="rate_per_minute"
              value={formData.rate_per_minute}
              onChange={handleChange}
              required
              className="w-full p-2 border border-gray-300 rounded mt-1"
            />
          </label>
          <label className="block">
            Experience Years:
            <input
              type="number"
              name="experience_years"
              value={formData.experience_years}
              onChange={handleChange}
              required
              className="w-full p-2 border border-gray-300 rounded mt-1"
            />
          </label>
          <label className="block">
            Education:
            <textarea
              name="education"
              value={formData.education}
              onChange={handleChange}
              className="w-full p-2 border border-gray-300 rounded mt-1"
            />
          </label>
          <label className="block">
            Certifications:
            <textarea
              name="certifications"
              value={formData.certifications}
              onChange={handleChange}
              className="w-full p-2 border border-gray-300 rounded mt-1"
            />
          </label>
          <label className="block">
            Profile Image URL:
            <input
              type="text"
              name="avatar_url"
              value={formData.avatar_url}
              onChange={handleChange}
              className="w-full p-2 border border-gray-300 rounded mt-1"
            />
          </label>
          <div className="flex space-x-2">
            <button type="submit" className="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">Save</button>
            <button type="button" onClick={onClose} className="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600">Cancel</button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default ListenerEditForm;