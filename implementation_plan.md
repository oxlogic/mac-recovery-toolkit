# Implementation Plan: Emergency User Data Backup Engine (Pre-Wipe Triage)

একটি ম্যাক ওএস রিস্টোর, ফরম্যাট বা নতুন করে ডিপ্লয় করার আগে ক্লায়েন্টের অমূল্য ডাটা নিরাপদে এক্সটার্নাল ড্রাইভ বা পেনড্রাইভে ব্যাকআপ নেওয়ার জন্য একটি স্বয়ংক্রিয় **Emergency User Data Backup Engine** যুক্ত করার পরিকল্পনা।

এই মডিউলটি লাইভ ম্যাক (Live macOS Desktop) এবং রিকভারি মোড (macOS Recovery Mode) উভয় জায়গায় কাজ করবে।

---

## User Review Required

> [!IMPORTANT]
> **ফাইলভল্ট (FileVault) ও ড্রাইভ আনলকিং নীতি:**
> - আধুনিক ম্যাকে (`Macintosh HD - Data`) এনক্রিপ্ট করা থাকলে রিকভারি মোডে সরাসরি রিড করা যায় না।
> - স্ক্রিপ্ট প্রথমে চেক করবে ড্রাইভ লক আছে কি না। লক থাকলে নিরাপদ পাসওয়ার্ড প্রম্পট দেবে এবং `diskutil apfs unlockVolume` দিয়ে মাউন্ট করবে।
> - লাইভ ম্যাকে এই পাসওয়ার্ড লাগবে না কারণ ম্যাক অলরেডি আনলকড।

> [!CAUTION]
> **স্পেস ও আবর্জনা ফিল্টারিং নীতি:**
> - ইউজারের পুরো ফোল্ডার ঢালাওভাবে কপি করলে `/Library/Caches` বা ব্রাউজার হিস্ট্রির কারণে ৮০ জিবি আবর্জনা কপি হয়ে সময় নষ্ট হয় ও পারমিশন এরর দেয়।
> - এই ইঞ্জিনে ইউজারের গুরুত্বপূর্ণ ফোল্ডারসমূহ (`Desktop`, `Documents`, `Downloads`, `Pictures`, `Movies`, `Music`, `iCloud CloudDocs`) অগ্রাধিকার ভিত্তিতে কপি হবে এবং অকেজো সিস্টেম ক্যাশ স্বয়ংক্রিয়ভাবে বাদ দেওয়া হবে।
> - কপি শুরুর আগে পেনড্রাইভে পর্যাপ্ত ফাঁকা জায়গা (Free Space) আছে কি না তা ১ সেকেন্ডে মিলিয়ে নেওয়া হবে।

---

## Proposed Changes & Architecture

### [Core Engine]

#### [MODIFY] [universal_mac.sh](file:///c:/Users/admin/Documents/universal_mac/universal_mac.sh)

1. **নতুন মডিউল ফাংশন: `menu_backup_data()`**
   - **ধাপ ১ (ভলিউম ডিটেকশন):** ইন্টারনাল এসএসডির `* - Data` ভলিউম খুঁজে বের করা। ড্রাইভ লক থাকলে `diskutil apfs unlockVolume` দিয়ে পাসওয়ার্ড চেয়ে আনলক করা।
   - **ধাপ ২ (ইউজার প্রোফাইল নির্বাচন):** `/Users` ফোল্ডার স্ক্যান করে আসল ইউজারদের তালিকা তৈরি (সিস্টেম ইউজার যেমন `Shared`, `daemon` বাদ দিয়ে)।
   - **ধাপ ৩ (টার্গেট ড্রাইভ নির্বাচন):** এক্সটার্নাল ব্যাকআপ পেনড্রাইভ বা হার্ডডিস্ক সিলেক্ট করা (`diskutil list external physical`)।
   - **ধাপ ৪ (স্পেস প্রি-ফ্লাইট চেক):** সোর্স ডাটার আনুমানিক সাইজ এবং টার্গেট পেনড্রাইভের ফ্রি স্পেস তুলনা করে দেখা।
   - **ধাপ ৫ (রেজিউমেবল `rsync` এক্সিকিউশন):**
     ```bash
     rsync -avP --partial --exclude="Library/Caches" "$source_user_dir" "$target_usb/Backup_${username}_${timestamp}/"
     ```
   - **ধাপ ৬ (রিপোর্ট ও নোটিফিকেশন):**
     - GUI মোডে সাকসেস নোটিফিকেশন: *"Backup Completed! Files safely stored on [Drive Name]"*।
     - CLI মোডে লাইভ প্রগ্রেস ও ফাইল ট্রান্সফার সামারি।

2. **মেইন মেনু আপডেট:**
   - মডিউল নম্বর ৫ হিসেবে **`5. Emergency User Data Backup (Pre-Wipe Triage)`** অন্তর্ভুক্ত করা।
   - পরবর্তী মডিউলগুলোর ক্রম ঠিক করা (Deployment = 6, Create USB = 7, Security = 8, Switch Mode = 9, Exit = 10)।

---

### [Documentation]

#### [MODIFY] [README.md](file:///c:/Users/admin/Documents/universal_mac/README.md)
- ইংরেজি ও বাংলা উভয় টেবিলে নতুন মডিউল ৫ (Emergency User Data Backup)-এর পূর্ণাঙ্গ বিবরণ ও ব্যবহারের নিয়ম যোগ করা।

---

## Verification Plan

### Automated Tests
1. ব্যাশ সিনট্যাক্স ভেরিফিকেশন:
   ```bash
   & "C:\Program Files\Git\bin\bash.exe" -n universal_mac.sh
   ```
2. পাইথন স্ক্রিপ্ট দিয়ে ইউনিক্স LF (`\n`) লাইন এন্ডিং ভেরিফিকেশন।

### Manual Logic Verification
- লাইভ ম্যাক এবং রিকভারি মোডের পাথ রেজোলিউশন টেস্ট (`Macintosh HD - Data` বনাম সরাসরি `/Users`)।
- এক্সটার্নাল ড্রাইভ ফিল্টারিং (ইন্টারনাল এসএসডিতে ব্যাকআপ নেওয়া ব্লক করা)।
- `rsync` আর্গুমেন্ট এবং এক্সক্লুশন রুলস টেস্ট।
