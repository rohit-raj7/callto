import React, { useState, useEffect } from 'react';
import { Plus, Edit2, Trash2, Save, X, ToggleLeft, ToggleRight, Loader2 } from 'lucide-react';
import { getRechargePacks, createRechargePack, updateRechargePack, deleteRechargePack } from '../services/api';
import Breadcrumb from '../components/Breadcrumb';
import { useNotifications } from '../contexts/NotificationContext';

const RechargePacks = () => {
  const [packs, setPacks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editingId, setEditingId] = useState(null);
  const [isAdding, setIsAdding] = useState(false);
  const [formData, setFormData] = useState({
    amount: '',
    extra_percent_or_amount: '',
    badge_text: '',
    is_active: true,
    sort_order: 0
  });
  const { addNotification } = useNotifications();

  useEffect(() => {
    fetchPacks();
  }, []);

  const fetchPacks = async () => {
    try {
      setLoading(true);
      const response = await getRechargePacks();
      if (response.data.success) {
        setPacks(response.data.data);
      }
    } catch (error) {
      console.error('Error fetching packs:', error);
      addNotification('Failed to fetch recharge packs', 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (pack) => {
    setEditingId(pack.id);
    setFormData({
      amount: pack.amount,
      extra_percent_or_amount: pack.extra_percent_or_amount,
      badge_text: pack.badge_text || '',
      is_active: pack.is_active,
      sort_order: pack.sort_order
    });
  };

  const handleCancel = () => {
    setEditingId(null);
    setIsAdding(false);
    setFormData({
      amount: '',
      extra_percent_or_amount: '',
      badge_text: '',
      is_active: true,
      sort_order: 0
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingId) {
        await updateRechargePack(editingId, formData);
        addNotification('Recharge pack updated successfully', 'success');
      } else {
        await createRechargePack(formData);
        addNotification('Recharge pack created successfully', 'success');
      }
      handleCancel();
      fetchPacks();
    } catch (error) {
      console.error('Error saving pack:', error);
      addNotification('Failed to save recharge pack', 'error');
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm('Are you sure you want to disable this pack?')) {
      try {
        await deleteRechargePack(id);
        addNotification('Recharge pack disabled', 'success');
        fetchPacks();
      } catch (error) {
        console.error('Error disabling pack:', error);
        addNotification('Failed to disable recharge pack', 'error');
      }
    }
  };

  const handleToggleActive = async (pack) => {
    try {
      await updateRechargePack(pack.id, { ...pack, is_active: !pack.is_active });
      addNotification(`Pack ${pack.is_active ? 'disabled' : 'enabled'} successfully`, 'success');
      fetchPacks();
    } catch (error) {
      console.error('Error toggling pack status:', error);
      addNotification('Failed to update pack status', 'error');
    }
  };

  if (loading && packs.length === 0) {
    return (
      <div className="min-h-[80vh] w-full bg-gray-50 dark:bg-gray-900 flex items-center justify-center">
        <div className="flex items-center gap-3 text-gray-600 dark:text-gray-300">
          <Loader2 className="w-6 h-6 animate-spin" />
          <span className="font-medium">Loading recharge packs</span>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-[80vh] w-full bg-gray-50 dark:bg-gray-900 py-8 px-4">
      <div className="max-w-7xl mx-auto">
        <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-6 mb-8">
          <div>
            <Breadcrumb items={[{ label: 'Dashboard', path: '/admin-no-all-call/dashboard' }, { label: 'Recharge Packs' }]} />
            <div className="flex items-center gap-3 mt-3">
              <div className="w-11 h-11 rounded-xl bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center shadow-lg">
                <Plus className="w-5 h-5 text-white" />
              </div>
              <div>
                <h1 className="text-3xl font-extrabold bg-gradient-to-r from-gray-900 via-gray-800 to-gray-900 dark:from-white dark:via-gray-200 dark:to-white bg-clip-text text-transparent">
                  Recharge Packs
                </h1>
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  Manage pricing, bonuses, and visibility for wallet top-ups
                </p>
              </div>
            </div>
          </div>
          <button
            onClick={() => setIsAdding(true)}
            disabled={isAdding || editingId}
            className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-blue-600 to-blue-700 text-white font-semibold shadow-lg hover:shadow-xl hover:from-blue-700 hover:to-blue-800 transition-all disabled:opacity-60 disabled:cursor-not-allowed"
          >
            <Plus className="w-5 h-5" />
            <span>Add New Pack</span>
          </button>
        </div>

      {(isAdding || editingId) && (
        <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700 p-6 mb-8">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h2 className="text-xl font-bold text-gray-900 dark:text-white">
                {editingId ? 'Edit Recharge Pack' : 'Add New Recharge Pack'}
              </h2>
              <p className="text-sm text-gray-600 dark:text-gray-400">
                Configure amount, bonus, badge, and display order
              </p>
            </div>
            <div className="px-3 py-1 rounded-full text-xs font-semibold bg-indigo-50 text-indigo-600 dark:bg-indigo-900/40 dark:text-indigo-300">
              {editingId ? 'Editing' : 'New Pack'}
            </div>
          </div>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
            <div className="space-y-1.5">
              <label className="block text-sm font-semibold text-gray-700 dark:text-gray-300">Amount (₹)</label>
              <input
                type="number"
                value={formData.amount}
                onChange={(e) => setFormData({ ...formData, amount: e.target.value })}
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-900/60 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
                required
              />
            </div>
            <div className="space-y-1.5">
              <label className="block text-sm font-semibold text-gray-700 dark:text-gray-300">Extra Bonus (%)</label>
              <input
                type="number"
                value={formData.extra_percent_or_amount}
                onChange={(e) => setFormData({ ...formData, extra_percent_or_amount: e.target.value })}
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-900/60 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
                required
              />
            </div>
            <div className="space-y-1.5">
              <label className="block text-sm font-semibold text-gray-700 dark:text-gray-300">Badge Label</label>
              <input
                type="text"
                value={formData.badge_text}
                onChange={(e) => setFormData({ ...formData, badge_text: e.target.value })}
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-900/60 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Popular, Best Value"
              />
            </div>
            <div className="space-y-1.5">
              <label className="block text-sm font-semibold text-gray-700 dark:text-gray-300">Sort Order</label>
              <input
                type="number"
                value={formData.sort_order}
                onChange={(e) => setFormData({ ...formData, sort_order: e.target.value })}
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-900/60 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div className="flex items-center gap-3 md:col-span-2 xl:col-span-1">
              <label className="inline-flex items-center gap-2 text-sm font-semibold text-gray-700 dark:text-gray-300">
                <input
                  type="checkbox"
                  checked={formData.is_active}
                  onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                  className="w-4 h-4 text-blue-600 rounded"
                />
                Active
              </label>
              <span className="text-xs text-gray-500 dark:text-gray-400">
                Active packs are visible in the mobile app
              </span>
            </div>
            <div className="flex items-end gap-3 md:col-span-2 xl:col-span-1">
              <button
                type="submit"
                className="inline-flex items-center gap-2 bg-emerald-600 hover:bg-emerald-700 text-white px-6 py-2.5 rounded-xl transition-colors font-semibold"
              >
                <Save className="w-5 h-5" />
                <span>Save Pack</span>
              </button>
              <button
                type="button"
                onClick={handleCancel}
                className="inline-flex items-center gap-2 bg-gray-100 hover:bg-gray-200 text-gray-800 dark:bg-gray-700 dark:hover:bg-gray-600 dark:text-gray-100 px-6 py-2.5 rounded-xl transition-colors font-semibold"
              >
                <X className="w-5 h-5" />
                <span>Cancel</span>
              </button>
            </div>
          </form>
        </div>
      )}

        <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 px-6 py-5 border-b border-gray-200 dark:border-gray-700 bg-gray-50/70 dark:bg-gray-900/60">
            <div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white">All Packs</h3>
              <p className="text-sm text-gray-600 dark:text-gray-400">
                {packs.length} total packs
              </p>
            </div>
            <div className="flex items-center gap-2 text-xs font-semibold text-gray-500 dark:text-gray-400">
              <span className="px-2 py-1 rounded-full bg-emerald-50 text-emerald-600 dark:bg-emerald-900/40 dark:text-emerald-300">
                Active
              </span>
              <span className="px-2 py-1 rounded-full bg-rose-50 text-rose-600 dark:bg-rose-900/40 dark:text-rose-300">
                Inactive
              </span>
            </div>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead className="bg-white dark:bg-gray-800">
                <tr className="text-xs uppercase tracking-wider text-gray-500 dark:text-gray-400">
                  <th className="px-6 py-4 font-semibold">Sort</th>
                  <th className="px-6 py-4 font-semibold">Amount</th>
                  <th className="px-6 py-4 font-semibold">Bonus</th>
                  <th className="px-6 py-4 font-semibold">Badge</th>
                  <th className="px-6 py-4 font-semibold">Status</th>
                  <th className="px-6 py-4 font-semibold text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
                {packs.map((pack) => (
                  <tr key={pack.id} className="hover:bg-gray-50 dark:hover:bg-gray-900/40 transition-colors">
                    <td className="px-6 py-4 text-sm text-gray-700 dark:text-gray-200">{pack.sort_order}</td>
                    <td className="px-6 py-4 text-sm font-semibold text-gray-900 dark:text-white">₹{pack.amount}</td>
                    <td className="px-6 py-4 text-sm text-gray-700 dark:text-gray-200">
                      {pack.extra_percent_or_amount}%
                    </td>
                    <td className="px-6 py-4 text-sm">
                      {pack.badge_text ? (
                        <span className="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-semibold bg-indigo-50 text-indigo-700 dark:bg-indigo-900/40 dark:text-indigo-300">
                          {pack.badge_text}
                        </span>
                      ) : (
                        <span className="text-gray-400 text-xs">None</span>
                      )}
                    </td>
                    <td className="px-6 py-4 text-sm">
                      <button
                        onClick={() => handleToggleActive(pack)}
                        className={`inline-flex items-center gap-1.5 font-semibold ${
                          pack.is_active ? 'text-emerald-600 dark:text-emerald-400' : 'text-rose-600 dark:text-rose-400'
                        }`}
                      >
                        {pack.is_active ? <ToggleRight className="w-6 h-6" /> : <ToggleLeft className="w-6 h-6" />}
                        <span>{pack.is_active ? 'Active' : 'Inactive'}</span>
                      </button>
                    </td>
                    <td className="px-6 py-4 text-sm">
                      <div className="flex items-center justify-end gap-2">
                        <button
                          onClick={() => handleEdit(pack)}
                          className="p-2 rounded-lg border border-blue-100 text-blue-600 hover:bg-blue-50 dark:border-blue-900/40 dark:hover:bg-blue-900/40 transition-colors"
                          title="Edit"
                        >
                          <Edit2 className="w-4.5 h-4.5" />
                        </button>
                        <button
                          onClick={() => handleDelete(pack.id)}
                          className="p-2 rounded-lg border border-rose-100 text-rose-600 hover:bg-rose-50 dark:border-rose-900/40 dark:hover:bg-rose-900/40 transition-colors"
                          title="Disable"
                        >
                          <Trash2 className="w-4.5 h-4.5" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
                {packs.length === 0 && (
                  <tr>
                    <td colSpan="6" className="px-6 py-16 text-center text-gray-500 dark:text-gray-400">
                      <div className="flex flex-col items-center gap-2">
                        <div className="w-12 h-12 rounded-full bg-gray-100 dark:bg-gray-700 flex items-center justify-center">
                          <Plus className="w-5 h-5 text-gray-400 dark:text-gray-300" />
                        </div>
                        <p className="font-semibold">No recharge packs found</p>
                        <p className="text-sm">Create a new pack to get started</p>
                      </div>
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
};

export default RechargePacks;
