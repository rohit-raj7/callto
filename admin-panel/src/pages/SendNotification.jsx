import React, { useEffect, useMemo, useState } from 'react';
import { Bell, Calendar, Clock, Send, Smartphone, Users, Headphones, Sparkles } from 'lucide-react';
/* eslint-disable no-unused-vars */
import { motion, AnimatePresence } from 'framer-motion';
import api, { getOutbox, updateOutbox, deleteOutbox } from '../services/api';

const NotificationPanel = ({
  title,
  targetLabel,
  scheduleEnabled,
  onScheduleToggle,
  repeatValue,
  onRepeatChange,
  Icon,
  accentColor = "pink",
  notifTitle,
  setNotifTitle,
  notifBody,
  setNotifBody,
  dateValue,
  setDateValue,
  timeValue,
  setTimeValue,
  targetAll,
  setTargetAll,
  targetIds,
  setTargetIds,
  onSend,
  sending,
  feedback
}) => {
  const lowerTarget = targetLabel.toLowerCase();
  
  const colorMap = {
    pink: {
      bg: "bg-pink-50 dark:bg-pink-900/10",
      border: "border-pink-100 dark:border-pink-900/20",
      text: "text-pink-600 dark:text-pink-400",
      button: "bg-pink-600 hover:bg-pink-700 shadow-pink-200 dark:shadow-none",
      iconBg: "bg-pink-100 dark:bg-pink-900/30",
      focus: "focus:ring-pink-500"
    },
    purple: {
      bg: "bg-purple-50 dark:bg-purple-900/10",
      border: "border-purple-100 dark:border-purple-900/20",
      text: "text-purple-600 dark:text-purple-400",
      button: "bg-purple-600 hover:bg-purple-700 shadow-purple-200 dark:shadow-none",
      iconBg: "bg-purple-100 dark:bg-purple-900/30",
      focus: "focus:ring-purple-500"
    }
  };

  const colors = colorMap[accentColor];

  return (
    <motion.div 
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="space-y-6"
    >
      <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-xl shadow-gray-200/50 dark:shadow-none p-8 transition-all hover:shadow-2xl hover:shadow-gray-300/50 dark:hover:shadow-none">
        <div className="flex items-start justify-between gap-4">
          <div className="flex gap-4">
            <div className={`w-14 h-14 rounded-2xl ${colors.iconBg} flex items-center justify-center shadow-inner`}>
              <Icon className={`w-7 h-7 ${colors.text}`} strokeWidth={2.5} />
            </div>
            <div>
              <h2 className="text-2xl font-bold text-gray-900 dark:text-white tracking-tight">{title}</h2>
              <p className="text-sm font-medium text-gray-500 dark:text-gray-400 mt-1 flex items-center gap-1">
                <Smartphone className="w-3.5 h-3.5" />
                Mobile app push notifications
              </p>
            </div>
          </div>
          <div className="flex items-center gap-1 text-[10px] font-bold uppercase tracking-widest text-gray-400 bg-gray-50 dark:bg-gray-900/50 px-2 py-1 rounded-md border border-gray-100 dark:border-gray-800">
            <Sparkles className="w-3 h-3" />
            Active
          </div>
        </div>

        <div className="mt-8 space-y-6">
          <div className="group">
            <label className="block text-xs font-bold text-gray-400 uppercase tracking-widest mb-2 ml-1 group-focus-within:text-pink-500 transition-colors">
              Notification Title
            </label>
            <input
              type="text"
              placeholder={`e.g. Welcome to CallTo!`}
              className={`w-full px-5 py-3.5 border border-gray-200 dark:border-gray-700 rounded-xl bg-gray-50/50 dark:bg-gray-900 text-gray-900 dark:text-white ${colors.focus} focus:ring-2 focus:border-transparent transition-all placeholder:text-gray-400`}
              value={notifTitle}
              onChange={(e) => setNotifTitle(e.target.value)}
            />
          </div>

          <div className="group">
            <label className="block text-xs font-bold text-gray-400 uppercase tracking-widest mb-2 ml-1 group-focus-within:text-pink-500 transition-colors">
              Message Content
            </label>
            <textarea
              rows={4}
              placeholder={`Write a friendly message for your ${lowerTarget}s...`}
              className={`w-full px-5 py-3.5 border border-gray-200 dark:border-gray-700 rounded-xl bg-gray-50/50 dark:bg-gray-900 text-gray-900 dark:text-white ${colors.focus} focus:ring-2 focus:border-transparent transition-all placeholder:text-gray-400 resize-none`}
              value={notifBody}
              onChange={(e) => setNotifBody(e.target.value)}
            />
          </div>

          <div className={`flex items-center justify-between gap-4 p-5 rounded-2xl ${colors.bg} border ${colors.border} transition-colors`}>
            <div className="flex gap-3 items-center">
              <div className={`p-2 rounded-lg bg-white dark:bg-gray-800 shadow-sm ${colors.text}`}>
                <Calendar className="w-5 h-5" />
              </div>
              <div>
                <p className="text-sm font-bold text-gray-800 dark:text-gray-200">Schedule Delivery</p>
                <p className="text-xs font-medium text-gray-500 dark:text-gray-400 mt-0.5">
                  Send later or set recurring alerts
                </p>
              </div>
            </div>
            <label className="inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                className="sr-only peer"
                checked={scheduleEnabled}
                onChange={(event) => onScheduleToggle(event.target.checked)}
              />
              <div className={`w-14 h-7 bg-gray-300 peer-focus:outline-none rounded-full peer dark:bg-gray-700 peer-checked:after:translate-x-7 after:content-[''] after:absolute after:top-[4px] after:left-[4px] after:bg-white after:rounded-full after:h-[20px] after:w-[20px] after:transition-all peer-checked:bg-gradient-to-r from-pink-500 to-rose-500 relative shadow-inner`} />
            </label>
          </div>

          <AnimatePresence>
            {scheduleEnabled && (
              <motion.div 
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                exit={{ opacity: 0, height: 0 }}
                className="overflow-hidden"
              >
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-5 pt-2">
                  <div className="group">
                    <label className="block text-xs font-bold text-gray-400 uppercase tracking-widest mb-2 ml-1">
                      Target Date
                    </label>
                    <div className="relative">
                      <Calendar className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 group-focus-within:text-pink-500 transition-colors" />
                      <input
                        type="date"
                        className={`w-full pl-12 pr-5 py-3.5 border border-gray-200 dark:border-gray-700 rounded-xl bg-gray-50/50 dark:bg-gray-900 text-gray-900 dark:text-white ${colors.focus} focus:ring-2 focus:border-transparent transition-all`}
                        value={dateValue}
                        onChange={(e) => setDateValue(e.target.value)}
                      />
                    </div>
                  </div>

                  <div className="group">
                    <label className="block text-xs font-bold text-gray-400 uppercase tracking-widest mb-2 ml-1">
                      Delivery Time
                    </label>
                    <div className="relative">
                      <Clock className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 group-focus-within:text-pink-500 transition-colors" />
                      <input
                        type="time"
                        className={`w-full pl-12 pr-5 py-3.5 border border-gray-200 dark:border-gray-700 rounded-xl bg-gray-50/50 dark:bg-gray-900 text-gray-900 dark:text-white ${colors.focus} focus:ring-2 focus:border-transparent transition-all`}
                        value={timeValue}
                        onChange={(e) => setTimeValue(e.target.value)}
                      />
                    </div>
                  </div>

                  <div className="sm:col-span-2">
                    <label className="block text-xs font-bold text-gray-400 uppercase tracking-widest mb-3 ml-1">
                      Repeat Settings
                    </label>
                    <div className="flex flex-wrap gap-3">
                      {['daily', 'weekly'].map((option) => (
                        <label
                          key={option}
                          className={`flex items-center gap-3 px-6 py-3 rounded-xl border-2 text-sm font-bold cursor-pointer transition-all duration-300 ${
                            repeatValue === option
                              ? 'bg-pink-50 border-pink-500 text-pink-700 dark:bg-pink-900/30 dark:border-pink-400 dark:text-pink-200 shadow-lg shadow-pink-100 dark:shadow-none scale-[1.02]'
                              : 'border-gray-100 text-gray-500 dark:border-gray-700 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 hover:border-gray-200'
                          }`}
                        >
                          <input
                            type="radio"
                            name={`${lowerTarget}-repeat`}
                            value={option}
                            checked={repeatValue === option}
                            onChange={(event) => onRepeatChange(event.target.value)}
                            className="hidden"
                          />
                          <div className={`w-4 h-4 rounded-full border-2 flex items-center justify-center ${repeatValue === option ? 'border-pink-500' : 'border-gray-300'}`}>
                            {repeatValue === option && <div className="w-2 h-2 rounded-full bg-pink-500" />}
                          </div>
                          {option.charAt(0).toUpperCase() + option.slice(1)}
                        </label>
                      ))}
                    </div>
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
            <div className="group">
              <label className="block text-xs font-bold text-gray-400 uppercase tracking-widest mb-2 ml-1">
                Target Audience
              </label>
              <div className="flex gap-3">
                <button
                  onClick={() => setTargetAll(true)}
                  className={`px-4 py-2 rounded-xl border-2 text-sm font-bold ${targetAll ? 'border-pink-500 text-pink-700' : 'border-gray-200 text-gray-500'}`}
                  type="button"
                >
                  All
                </button>
                <button
                  onClick={() => setTargetAll(false)}
                  className={`px-4 py-2 rounded-xl border-2 text-sm font-bold ${!targetAll ? 'border-pink-500 text-pink-700' : 'border-gray-200 text-gray-500'}`}
                  type="button"
                >
                  Selected IDs
                </button>
              </div>
            </div>
            {!targetAll && (
              <div className="group">
                <label className="block text-xs font-bold text-gray-400 uppercase tracking-widest mb-2 ml-1">
                  IDs (comma separated UUIDs)
                </label>
                <input
                  type="text"
                  placeholder="id1, id2, id3"
                  className={`w-full px-5 py-3.5 border border-gray-200 dark:border-gray-700 rounded-xl bg-gray-50/50 dark:bg-gray-900 text-gray-900 dark:text-white ${colors.focus} focus:ring-2 focus:border-transparent transition-all placeholder:text-gray-400`}
                  value={targetIds}
                  onChange={(e) => setTargetIds(e.target.value)}
                />
              </div>
            )}
          </div>

          <div className="pt-4">
            <motion.button 
              whileHover={{ scale: 1.01 }}
              whileTap={{ scale: 0.98 }}
              className={`w-full flex items-center justify-center gap-2 py-4 rounded-2xl ${colors.button} text-white font-bold text-lg transition-all shadow-xl shadow-pink-200/50 dark:shadow-none hover:shadow-2xl`}
              onClick={onSend}
              disabled={sending}
            >
              <Send className="w-5 h-5" />
              Push to {targetLabel}s
            </motion.button>
            {feedback && (
              <div className="mt-3 text-sm font-medium">
                <span className={feedback.type === 'error' ? 'text-red-600' : 'text-green-600'}>
                  {feedback.message}
                </span>
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-xl shadow-gray-200/50 dark:shadow-none p-8 overflow-hidden relative">
        <div className="absolute top-0 right-0 p-4 opacity-5">
           <Bell className="w-32 h-32 rotate-12" />
        </div>
        <div className="flex items-center justify-between relative z-10">
          <div>
            <h3 className="text-lg font-bold text-gray-900 dark:text-white flex items-center gap-2">
              <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
              Live Feed
            </h3>
            <p className="text-xs font-medium text-gray-500 dark:text-gray-400 mt-0.5">
              Recent activity for {lowerTarget} notifications
            </p>
          </div>
          <div className="flex items-center gap-1 text-[9px] font-black uppercase tracking-tighter text-blue-500 bg-blue-50 dark:bg-blue-900/20 px-2 py-1 rounded border border-blue-100 dark:border-blue-800">
            Preview Mode
          </div>
        </div>

        <div className="mt-6 space-y-4 relative z-10">
          <div className="flex items-center gap-4 p-4 rounded-xl border border-dashed border-gray-200 dark:border-gray-700 bg-gray-50/50 dark:bg-gray-900/40">
            <div className="w-10 h-10 rounded-full bg-white dark:bg-gray-800 flex items-center justify-center shadow-sm border border-gray-100 dark:border-gray-700">
              <Bell className="w-5 h-5 text-gray-300" />
            </div>
            <div>
              <p className="text-sm font-bold text-gray-700 dark:text-gray-200">Listening for updates...</p>
              <p className="text-xs font-medium text-gray-500 dark:text-gray-400">
                Real-time delivery status will appear here.
              </p>
            </div>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {['Scheduled for 2,400+ users', 'Delivered to active listeners'].map((text, idx) => (
              <div
                key={text}
                className={`p-4 rounded-xl ${idx === 0 ? 'bg-amber-50 text-amber-700 border border-amber-100' : 'bg-emerald-50 text-emerald-700 border border-emerald-100'} dark:bg-gray-700/50 dark:text-gray-300 dark:border-gray-700 text-[11px] font-bold flex items-center gap-2`}
              >
                <div className={`w-1.5 h-1.5 rounded-full ${idx === 0 ? 'bg-amber-500' : 'bg-emerald-500'}`} />
                {text}
              </div>
            ))}
          </div>
        </div>
      </div>
    </motion.div>
  );
};

const SendNotification = () => {
  const [userScheduleEnabled, setUserScheduleEnabled] = useState(false);
  const [listenerScheduleEnabled, setListenerScheduleEnabled] = useState(false);
  const [userRepeat, setUserRepeat] = useState('daily');
  const [listenerRepeat, setListenerRepeat] = useState('daily');
  const [userNotifTitle, setUserNotifTitle] = useState('');
  const [userNotifBody, setUserNotifBody] = useState('');
  const [userDate, setUserDate] = useState('');
  const [userTime, setUserTime] = useState('');
  const [userTargetAll, setUserTargetAll] = useState(true);
  const [userTargetIds, setUserTargetIds] = useState('');
  const [listenerNotifTitle, setListenerNotifTitle] = useState('');
  const [listenerNotifBody, setListenerNotifBody] = useState('');
  const [listenerDate, setListenerDate] = useState('');
  const [listenerTime, setListenerTime] = useState('');
  const [listenerTargetAll, setListenerTargetAll] = useState(true);
  const [listenerTargetIds, setListenerTargetIds] = useState('');
  const [sendingUser, setSendingUser] = useState(false);
  const [sendingListener, setSendingListener] = useState(false);
  const [feedbackUser, setFeedbackUser] = useState(null);
  const [feedbackListener, setFeedbackListener] = useState(null);
  const [outboxLoading, setOutboxLoading] = useState(false);
  const [outboxError, setOutboxError] = useState(null);
  const [outboxItems, setOutboxItems] = useState([]);
  const groupedOutbox = useMemo(() => {
    const users = outboxItems.filter((o) => o.target_role === 'USER');
    const listeners = outboxItems.filter((o) => o.target_role === 'LISTENER');
    return { users, listeners };
  }, [outboxItems]);
  const [editOpen, setEditOpen] = useState(false);
  const [editItem, setEditItem] = useState(null);
  const [editTitle, setEditTitle] = useState('');
  const [editBody, setEditBody] = useState('');
  const [editDate, setEditDate] = useState('');
  const [editTime, setEditTime] = useState('');
  const [editRepeat, setEditRepeat] = useState('');
  const [editTargetAll, setEditTargetAll] = useState(true);
  const [editTargetIds, setEditTargetIds] = useState('');

  const buildScheduleAt = (date, time) => {
    if (!date || !time) return null;
    const iso = new Date(`${date}T${time}:00`).toISOString();
    return iso;
  };

  const parseIds = (text) => {
    return text
      .split(',')
      .map((s) => s.trim())
      .filter((s) => s.length > 0);
  };

  const sendToRole = async (role) => {
    const isUser = role === 'USER';
    const title = isUser ? userNotifTitle : listenerNotifTitle;
    const body = isUser ? userNotifBody : listenerNotifBody;
    const scheduleAt = isUser
      ? buildScheduleAt(userDate, userTime)
      : buildScheduleAt(listenerDate, listenerTime);
    const targetAll = isUser ? userTargetAll : listenerTargetAll;
    const idsText = isUser ? userTargetIds : listenerTargetIds;
    const targetUserIds = targetAll ? null : parseIds(idsText);
    const schedEnabled = isUser ? userScheduleEnabled : listenerScheduleEnabled;
    const repeat = isUser ? userRepeat : listenerRepeat;

    if (!title || !body) {
      (isUser ? setFeedbackUser : setFeedbackListener)({ type: 'error', message: 'Title and Message are required' });
      return;
    }
    (isUser ? setSendingUser : setSendingListener)(true);
    (isUser ? setFeedbackUser : setFeedbackListener)(null);
    try {
      const res = await api.post('/notifications/outbox', {
        title,
        body,
        targetRole: role,
        targetUserIds,
        scheduleAt: schedEnabled ? scheduleAt : null,
        repeatInterval: schedEnabled ? repeat : null,
      });
      (isUser ? setFeedbackUser : setFeedbackListener)({ type: 'success', message: 'Notification scheduled' });
      await fetchOutbox();
    } catch (e) {
      (isUser ? setFeedbackUser : setFeedbackListener)({ type: 'error', message: 'Failed to schedule' });
    } finally {
      (isUser ? setSendingUser : setSendingListener)(false);
    }
  };

  const fetchOutbox = async () => {
    setOutboxLoading(true);
    setOutboxError(null);
    try {
      const res = await getOutbox({ page: 1, limit: 100 });
      setOutboxItems(res.data?.outbox || []);
    } catch (e) {
      setOutboxError('Failed to load scheduled notifications');
    } finally {
      setOutboxLoading(false);
    }
  };

  const openEdit = (item) => {
    setEditItem(item);
    setEditTitle(item.title || '');
    setEditBody(item.body || '');
    const d = item.schedule_at ? new Date(item.schedule_at) : null;
    setEditDate(d ? String(d.toISOString()).slice(0, 10) : '');
    setEditTime(d ? d.toISOString().slice(11, 16) : '');
    setEditRepeat(item.repeat_interval || '');
    const hasIds = Array.isArray(item.target_user_ids) && item.target_user_ids.length > 0;
    setEditTargetAll(!hasIds);
    setEditTargetIds(hasIds ? item.target_user_ids.join(',') : '');
    setEditOpen(true);
  };

  const closeEdit = () => {
    setEditOpen(false);
    setEditItem(null);
  };

  const saveEdit = async () => {
    if (!editItem) return;
    const scheduleAt = editDate && editTime ? new Date(`${editDate}T${editTime}:00`).toISOString() : null;
    const targetUserIds = editTargetAll
      ? null
      : editTargetIds
          .split(',')
          .map((s) => s.trim())
          .filter((s) => s.length > 0);
    const payload = {
      title: editTitle,
      body: editBody,
      scheduleAt,
      repeatInterval: editRepeat || null,
      targetUserIds
    };
    try {
      await updateOutbox(editItem.id, payload);
      closeEdit();
      await fetchOutbox();
    } catch {
      setOutboxError('Failed to update notification');
    }
  };

  const confirmDelete = async (item) => {
    try {
      await deleteOutbox(item.id);
      await fetchOutbox();
    } catch {
      setOutboxError('Failed to delete notification');
    }
  };

  useEffect(() => {
    fetchOutbox();
  }, []);

  return (
    <>
    <div className="min-h-screen bg-[#FDF2F8] dark:bg-gray-950 p-4 lg:p-8">
      <div className="max-w-7xl mx-auto">
        <div className="relative mb-12 overflow-hidden rounded-3xl bg-gradient-to-r from-pink-500 via-rose-500 to-purple-600 p-8 lg:p-12 shadow-2xl shadow-pink-200 dark:shadow-none">
          <div className="absolute top-0 right-0 -mt-10 -mr-10 opacity-10">
            <Bell className="w-64 h-64 text-white rotate-12" />
          </div>
          <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
            <div>
              <motion.div 
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/20 backdrop-blur-md text-white text-xs font-bold uppercase tracking-widest mb-4"
              >
                <Sparkles className="w-3.5 h-3.5" />
                Notification Center
              </motion.div>
              <motion.h1 
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                className="text-4xl lg:text-5xl font-black text-white tracking-tight"
              >
                Reach Your Community
              </motion.h1>
              <motion.p 
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.1 }}
                className="text-pink-100 text-lg font-medium mt-3 max-w-xl"
              >
                Send instant push notifications and keep your users and listeners engaged with the latest updates.
              </motion.p>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-12">
          <NotificationPanel
            title="User Community"
            targetLabel="User"
            Icon={Users}
            scheduleEnabled={userScheduleEnabled}
            onScheduleToggle={setUserScheduleEnabled}
            repeatValue={userRepeat}
            onRepeatChange={setUserRepeat}
            accentColor="pink"
            notifTitle={userNotifTitle}
            setNotifTitle={setUserNotifTitle}
            notifBody={userNotifBody}
            setNotifBody={setUserNotifBody}
            dateValue={userDate}
            setDateValue={setUserDate}
            timeValue={userTime}
            setTimeValue={setUserTime}
            targetAll={userTargetAll}
            setTargetAll={setUserTargetAll}
            targetIds={userTargetIds}
            setTargetIds={setUserTargetIds}
            onSend={() => sendToRole('USER')}
            sending={sendingUser}
            feedback={feedbackUser}
          />
          <NotificationPanel
            title="Expert Listeners"
            targetLabel="Listener"
            Icon={Headphones}
            scheduleEnabled={listenerScheduleEnabled}
            onScheduleToggle={setListenerScheduleEnabled}
            repeatValue={listenerRepeat}
            onRepeatChange={setListenerRepeat}
            accentColor="purple"
            notifTitle={listenerNotifTitle}
            setNotifTitle={setListenerNotifTitle}
            notifBody={listenerNotifBody}
            setNotifBody={setListenerNotifBody}
            dateValue={listenerDate}
            setDateValue={setListenerDate}
            timeValue={listenerTime}
            setTimeValue={setListenerTime}
            targetAll={listenerTargetAll}
            setTargetAll={setListenerTargetAll}
            targetIds={listenerTargetIds}
            setTargetIds={setListenerTargetIds}
            onSend={() => sendToRole('LISTENER')}
            sending={sendingListener}
            feedback={feedbackListener}
          />
        </div>
        <div className="mt-12 bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-xl p-8">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-xl font-bold text-gray-900 dark:text-white flex items-center gap-2">
                <Bell className="w-5 h-5" />
                Scheduled Notifications
              </h3>
              <p className="text-xs font-medium text-gray-500 dark:text-gray-400 mt-1">
                All pending and recent notifications
              </p>
            </div>
            <button
              onClick={fetchOutbox}
              className="px-4 py-2 rounded-xl bg-pink-600 hover:bg-pink-700 text-white text-sm font-bold"
              type="button"
            >
              Refresh
            </button>
          </div>
          {outboxLoading && (
            <div className="mt-6 text-sm font-medium text-gray-500 dark:text-gray-400">Loading…</div>
          )}
          {outboxError && (
            <div className="mt-6 text-sm font-medium text-red-600">{outboxError}</div>
          )}
          {!outboxLoading && !outboxError && (
            <div className="mt-8 grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div className="rounded-xl border border-gray-100 dark:border-gray-700 p-4">
                <div className="flex items-center gap-2 mb-3">
                  <Users className="w-4 h-4 text-pink-600" />
                  <span className="text-sm font-bold text-gray-700 dark:text-gray-200">Users</span>
                </div>
                <div className="space-y-3">
                  {groupedOutbox.users.length === 0 && (
                    <div className="text-xs font-medium text-gray-500 dark:text-gray-400">No scheduled items</div>
                  )}
                  {groupedOutbox.users.map((item) => (
                    <div key={item.id} className="p-4 rounded-lg bg-gray-50/50 dark:bg-gray-900/40 border border-gray-100 dark:border-gray-700">
                      <div className="flex items-center justify-between">
                        <div className="text-sm font-bold text-gray-800 dark:text-gray-200">{item.title}</div>
                        <span className={`text-[10px] font-bold px-2 py-1 rounded ${
                          item.status === 'PENDING' ? 'bg-amber-100 text-amber-700' :
                          item.status === 'SENT' ? 'bg-emerald-100 text-emerald-700' :
                          'bg-red-100 text-red-700'
                        }`}>
                          {item.status}
                        </span>
                      </div>
                      <div className="text-xs text-gray-600 dark:text-gray-400 mt-1">{item.body}</div>
                      <div className="mt-2 flex flex-wrap items-center gap-3 text-[11px]">
                        <div className="flex items-center gap-1 text-gray-500 dark:text-gray-400">
                          <Calendar className="w-3.5 h-3.5" />
                          <span>{item.schedule_at ? new Date(item.schedule_at).toLocaleString() : 'Immediate'}</span>
                        </div>
                        <div className="flex items-center gap-1 text-gray-500 dark:text-gray-400">
                          <Users className="w-3.5 h-3.5" />
                          <span>{Array.isArray(item.target_user_ids) && item.target_user_ids.length > 0 ? `Selected (${item.target_user_ids.length})` : 'All users'}</span>
                        </div>
                        <div className="flex items-center gap-1 text-gray-500 dark:text-gray-400">
                          <Clock className="w-3.5 h-3.5" />
                          <span>{new Date(item.created_at).toLocaleString()}</span>
                        </div>
                        {item.repeat_interval && (
                          <div className="flex items-center gap-1 text-blue-500 dark:text-blue-400 font-bold">
                            <Calendar className="w-3.5 h-3.5" />
                            <span>Repeats {item.repeat_interval}</span>
                          </div>
                        )}
                        <div className="ml-auto flex items-center gap-2">
                          <button
                            type="button"
                            onClick={() => openEdit(item)}
                            className="px-3 py-1 rounded-lg text-xs font-bold bg-yellow-500 text-white hover:bg-yellow-600"
                          >
                            Edit
                          </button>
                          <button
                            type="button"
                            onClick={() => confirmDelete(item)}
                            className="px-3 py-1 rounded-lg text-xs font-bold bg-red-500 text-white hover:bg-red-600"
                          >
                            Delete
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
              <div className="rounded-xl border border-gray-100 dark:border-gray-700 p-4">
                <div className="flex items-center gap-2 mb-3">
                  <Headphones className="w-4 h-4 text-purple-600" />
                  <span className="text-sm font-bold text-gray-700 dark:text-gray-200">Listeners</span>
                </div>
                <div className="space-y-3">
                  {groupedOutbox.listeners.length === 0 && (
                    <div className="text-xs font-medium text-gray-500 dark:text-gray-400">No scheduled items</div>
                  )}
                  {groupedOutbox.listeners.map((item) => (
                    <div key={item.id} className="p-4 rounded-lg bg-gray-50/50 dark:bg-gray-900/40 border border-gray-100 dark:border-gray-700">
                      <div className="flex items-center justify-between">
                        <div className="text-sm font-bold text-gray-800 dark:text-gray-200">{item.title}</div>
                        <span className={`text-[10px] font-bold px-2 py-1 rounded ${
                          item.status === 'PENDING' ? 'bg-amber-100 text-amber-700' :
                          item.status === 'SENT' ? 'bg-emerald-100 text-emerald-700' :
                          'bg-red-100 text-red-700'
                        }`}>
                          {item.status}
                        </span>
                      </div>
                      <div className="text-xs text-gray-600 dark:text-gray-400 mt-1">{item.body}</div>
                      <div className="mt-2 flex flex-wrap items-center gap-3 text-[11px]">
                        <div className="flex items-center gap-1 text-gray-500 dark:text-gray-400">
                          <Calendar className="w-3.5 h-3.5" />
                          <span>{item.schedule_at ? new Date(item.schedule_at).toLocaleString() : 'Immediate'}</span>
                        </div>
                        <div className="flex items-center gap-1 text-gray-500 dark:text-gray-400">
                          <Headphones className="w-3.5 h-3.5" />
                          <span>{Array.isArray(item.target_user_ids) && item.target_user_ids.length > 0 ? `Selected (${item.target_user_ids.length})` : 'All listeners'}</span>
                        </div>
                        <div className="flex items-center gap-1 text-gray-500 dark:text-gray-400">
                          <Clock className="w-3.5 h-3.5" />
                          <span>{new Date(item.created_at).toLocaleString()}</span>
                        </div>
                        {item.repeat_interval && (
                          <div className="flex items-center gap-1 text-blue-500 dark:text-blue-400 font-bold">
                            <Calendar className="w-3.5 h-3.5" />
                            <span>Repeats {item.repeat_interval}</span>
                          </div>
                        )}
                        <div className="ml-auto flex items-center gap-2">
                          <button
                            type="button"
                            onClick={() => openEdit(item)}
                            className="px-3 py-1 rounded-lg text-xs font-bold bg-yellow-500 text-white hover:bg-yellow-600"
                          >
                            Edit
                          </button>
                          <button
                            type="button"
                            onClick={() => confirmDelete(item)}
                            className="px-3 py-1 rounded-lg text-xs font-bold bg-red-500 text-white hover:bg-red-600"
                          >
                            Delete
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
    {editOpen && (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
        <div className="w-full max-w-lg bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 p-6">
          <div className="text-lg font-bold text-gray-900 dark:text-white mb-4">Edit Notification</div>
          <div className="space-y-4">
            <input
              type="text"
              className="w-full px-4 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50/50 dark:bg-gray-900 text-gray-900 dark:text-white"
              value={editTitle}
              onChange={(e) => setEditTitle(e.target.value)}
              placeholder="Title"
            />
            <textarea
              rows={4}
              className="w-full px-4 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50/50 dark:bg-gray-900 text-gray-900 dark:text-white"
              value={editBody}
              onChange={(e) => setEditBody(e.target.value)}
              placeholder="Message"
            />
            <div className="grid grid-cols-2 gap-3">
              <input
                type="date"
                className="w-full px-4 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50/50 dark:bg-gray-900 text-gray-900 dark:text-white"
                value={editDate}
                onChange={(e) => setEditDate(e.target.value)}
              />
              <input
                type="time"
                className="w-full px-4 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50/50 dark:bg-gray-900 text-gray-900 dark:text-white"
                value={editTime}
                onChange={(e) => setEditTime(e.target.value)}
              />
            </div>
            <div className="flex gap-3">
              {['', 'daily', 'weekly'].map((opt) => (
                <button
                  key={opt || 'none'}
                  type="button"
                  onClick={() => setEditRepeat(opt)}
                  className={`px-3 py-2 rounded-xl border text-sm font-bold ${
                    editRepeat === opt ? 'border-pink-500 text-pink-700' : 'border-gray-200 text-gray-500'
                  }`}
                >
                  {opt ? `Repeat ${opt}` : 'No repeat'}
                </button>
              ))}
            </div>
            <div className="flex gap-3">
              <button
                type="button"
                onClick={() => setEditTargetAll(true)}
                className={`px-3 py-2 rounded-xl border text-sm font-bold ${editTargetAll ? 'border-pink-500 text-pink-700' : 'border-gray-200 text-gray-500'}`}
              >
                All
              </button>
              <button
                type="button"
                onClick={() => setEditTargetAll(false)}
                className={`px-3 py-2 rounded-xl border text-sm font-bold ${!editTargetAll ? 'border-pink-500 text-pink-700' : 'border-gray-200 text-gray-500'}`}
              >
                Selected IDs
              </button>
            </div>
            {!editTargetAll && (
              <input
                type="text"
                className="w-full px-4 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50/50 dark:bg-gray-900 text-gray-900 dark:text-white"
                value={editTargetIds}
                onChange={(e) => setEditTargetIds(e.target.value)}
                placeholder="id1, id2, id3"
              />
            )}
          </div>
          <div className="mt-6 flex justify-end gap-3">
            <button
              type="button"
              onClick={closeEdit}
              className="px-4 py-2 rounded-xl border border-gray-200 text-gray-700 dark:border-gray-700 dark:text-gray-300"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={saveEdit}
              className="px-4 py-2 rounded-xl bg-pink-600 hover:bg-pink-700 text-white font-bold"
            >
              Save
            </button>
          </div>
        </div>
      </div>
    )}
    </>
  );
};

export default SendNotification;
