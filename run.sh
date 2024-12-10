#!/bin/bash

# گرفتن رمز عبور از کاربر
read -sp "لطفاً رمز عبور را وارد کنید: " password
echo

# دانلود فایل زیپ
echo "در حال دانلود فایل..."
curl -L https://github.com/Khajavi8056/token-crazy-inll/raw/main/install_project.zip -o install_project.zip

# استخراج فایل زیپ
echo "در حال استخراج فایل..."
unzip -P "$password" install_project.zip -d extracted_files

# رفتن به پوشه استخراج‌شده
cd extracted_files || { echo "پوشه پیدا نشد!"; exit 1; }

# اجرای فایل مورد نظر (تغییر دهید به فایل مناسب)
echo "در حال اجرای اسکریپت..."
bash install_project.sh
