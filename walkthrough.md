# Walkthrough: Universal Mac Repair Suite Architecture

[`universal_mac`](file:///c:/Users/admin/Documents/universal_mac) প্রোজেক্টটিতে লাইভ ম্যাক এবং রিকভারি মোডের জন্য একটি পূর্ণাঙ্গ, জিরো-ডিপেনডেন্সি এন্টারপ্রাইজ স্যুট প্রস্তুত করা হয়েছে।

---

## 🛠️ আর্কিটেকচার ওভারভিউ (Architecture Overview)

```
universal_mac/
  ├── Launch_Mac_Suite.command  (১ ক্লিকে ডাবল-ক্লিক করে চালানোর লঞ্চার)
  ├── universal_mac.sh          (মূল ইঞ্জিন - AppleScript GUI + Recovery CLI)
  └── README.md                 (আন্তর্জাতিক মানের দ্বিভাষিক ম্যানুয়াল)
```

---

## 🌟 নতুন যুক্ত হওয়া মূল ফিচারসমূহ:

### ১. মডিউল ৪: Quick Connect External USB / Hard Disk
- **উদ্দেশ্য:** উইন্ডোজ থেকে আসা ধীরগতির exFAT বা ড্রাইভ যা সহজে মাউন্ট হয় না সেগুলোকে ৩ সেকেন্ডে কানেক্ট করা।
- **কার্যপদ্ধতি:** ব্যাকগ্রাউন্ডের আটকে থাকা `fsck_exfat` ও `fsck_msdos` কিল করে এবং `diskutil mountDisk` দিয়ে সব এক্সটার্নাল ড্রাইভ সাথে সাথে মাউন্ট করে।

### ২. মডিউল ৫: Emergency User Data Backup (Pre-Wipe Triage)
- **উদ্দেশ্য:** ম্যাক ক্র্যাশ করলে বা ওএস দেওয়ার আগে কাস্টমারের ব্যক্তিগত ফাইল সুরক্ষিত রাখা।
- **স্বয়ংক্রিয় ভলিউম ডিটেকশন:** লাইভ ম্যাকে `/Users` এবং রিকভারি মোডে `Macintosh HD - Data` খুঁজে বের করে।
- **FileVault আনলকার:** এনক্রিপ্ট করা থাকলে নিরাপদ পাসওয়ার্ড প্রম্পট দিয়ে ড্রাইভ আনলক করে।
- **রেজুমেবল `rsync` ইঞ্জিন:** মাঝপথে ডিসকানেক্ট হলেও কোনো ফাইল নষ্ট হয় না, পুনরায় প্লাগ করলে বাকিটুকু কপি হয়।
- **আবর্জনা মুক্ত:** `/Library/Caches` বা ব্রাউজার হিস্ট্রির মতো অপ্রয়োজনীয় ভারী ফাইল বাদ দিয়ে শুধু কাজের ডাটা কপি করে।

---

## 📋 মোট মডিউল তালিকা (১০টি মডিউল):
1. **Hardware Diagnostics & Health** (SMART SSD, Battery, CPU, RAM)
2. **Network & Wi-Fi Management** (Scan, Connect, Apple Ping Test)
3. **Date & Time Synchronization** (Certificate Fix, sntp, ntpdate)
4. **Smart Disk Manager & Format** (Safe APFS/JHFS+, Quick Connect USB)
5. **Emergency User Data Backup** (Pre-Wipe Triage, Resumable Rsync)
6. **macOS Installer & Deployment** (USB Auto-Detect, startosinstall, CDN)
7. **Create Bootable USB Installer** (Auto-detect .app, Finder Browse)
8. **Advanced Security & NVRAM** (SIP, NVRAM Reset, Verbose Boot, bputil)
9. **Switch Mode** (GUI ⇄ CLI)
10. **Exit Suite**

---

## 🧪 ভেরিফিকেশন ফলাফল (Verification Results):

| ফাইল | টেস্ট | রেজাল্ট |
| :--- | :--- | :--- |
| `universal_mac.sh` | Bash Syntax Check (`bash -n`) | **PASSED (Exit Code: 0)** |
| `Launch_Mac_Suite.command` | Bash Syntax Check (`bash -n`) | **PASSED (Exit Code: 0)** |
| সমস্ত ফাইল | Unix Line Endings (LF `\n`) | **PASSED (Pure Unix LF)** |
