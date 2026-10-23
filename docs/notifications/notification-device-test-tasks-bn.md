# নোটিফিকেশন ইঞ্জিন: নিজের ডিভাইসে টেস্ট

V2 চালু: ২৩ অক্টোবর ২০২৬, রাত ১০:৩০, বাংলাদেশ সময়। বর্তমান engine production-এ সক্রিয়। বাস্তব device এবং pilot-এর ফল ব্যবহারকারীর পরীক্ষার পর নথিভুক্ত হবে।

## শুরু

https://yeasinh.me/mg-hrm/ খুলে একবার reload করুন। একই অনুমোদিত account দিয়ে Android ও Windows-এ login করুন। Notification settings-এ প্রতিটি device-এ Push allow/subscribe করুন এবং ToDo category-র notification ও System Push চালু রাখুন। Scheduler and delivery health-এ Engine: V2 enabled দেখাবে। Android browser/Windows browser ও OS notification permission উভয়ই allow রাখুন।

Push-এর পরীক্ষা সকাল ৯টা–সন্ধ্যা ৬টার মধ্যে করুন। বর্তমানে রাত; রাতেই পরীক্ষার কাজ save করা যাবে, কিন্তু তাৎক্ষণিক routine Push প্রত্যাশিত নয়। সকাল ও বিকেলের digest যথাক্রমে ৯:০৫ ও ৫:১৫; নতুন কাজ scheduler-এর পরবর্তী cycle-এ আসে, save-এর সঙ্গে তাৎক্ষণিক Push-এর নিশ্চয়তা নেই। Background Push দেখতে MG-HRM-এর দৃশ্যমান tab বন্ধ/পেছনে রাখুন; browser পুরোপুরি force-stop করবেন না।

সব কৃত্রিম কাজের নাম TEST দিয়ে শুরু করুন। আসল employee, transfer, payroll বা disciplinary record বদলাতে হবে না।

## পরীক্ষার কাজ

1. **Save/reload:** To-Do → Quick capture → My Task-এ `TEST-01 ফোনে তৈরি` save করুন। Reload করে এবং অন্য device-এ একই কাজটি ঠিক একবার দেখুন। একইভাবে Windows-এ `TEST-02 কম্পিউটারে তৈরি` করুন।
2. **Background Push ও tap:** অফিস সময়ে `TEST-03 গুরুত্বপূর্ণ কাজ` তৈরি করুন। Work steps → Edit action plan-এ Priority important, Next action এবং এখন থেকে প্রায় ৩০ মিনিট পরের deadline দিন; Save action plan করুন। দুই device-এ app পেছনে রেখে পরবর্তী scheduler cycle-এর alert দেখুন। Push চাপলে সঠিক কাজ খোলে কি না লিখুন। কোনো device-এ না এলে সময়, permission এবং settings-এর health message লিখুন; শুধু অপেক্ষা করেই pass ধরবেন না।
3. **Read বনাম completion:** TEST-03-এর notification Read করুন। মূল কাজ Open থাকা উচিত। তারপর Work steps-এ কাজের প্রয়োজনীয় ধাপ শেষ করে completion দিন; মূল কাজ সত্যিই বন্ধ হচ্ছে কি না দেখুন। পুরোনো notification history থাকতেই পারে; completed কাজের নতুন actionable alert আসা উচিত নয়।
4. **Snooze:** আলাদা TEST-04 কাজের Work steps-এ deadline-এর আগের একটি ছোট snooze দিন। Reload-এ সময়টি অক্ষত থাকা এবং snooze চলাকালে reminder দমন দেখুন। Notifications-এর Snooze শুধু inbox occurrence-এর; কাজের snooze দিতে Work steps ব্যবহার করুন।
5. **Manager workflow:** Inform to Manager-এ `TEST-05 অনুমতির অনুরোধ` তৈরি করুন। Work steps-এ Manager informed রেকর্ড করুন, তারপর কেবল এই TEST কাজের decision approved রেকর্ড করুন। অনুমোদন দেওয়ামাত্র সব যোগাযোগ/execution complete হওয়া উচিত নয়; প্রয়োজনীয় বাকি ধাপ দেখাবে।
6. **Offline retry:** app আগে খোলা অবস্থায় internet বন্ধ করে Quick capture-এ `TEST-06 অফলাইনে তৈরি` save করুন। Queued/pending অবস্থা দেখাবে। Internet চালু করে Pending saves → Retry connected saves করুন। Reload-এর পর একটিই কাজ থাকা উচিত। সফল sync না হওয়া পর্যন্ত browser data মুছবেন না।
7. **রাত ও digest:** রাতের TEST কাজ এবং কিছু অসম্পূর্ণ কাজ রেখে পরদিন সকালে দেখুন। রাতের routine Push হওয়া উচিত নয়; কাজ অক্ষত থাকবে। Notifications-এ ৯:০৫-এর morning digest বা ৫:১৫-এর wrap-up digest দেখুন; digest Read করলে source কাজ complete হওয়া উচিত নয়।

প্রতিটি ফল লিখুন: TEST নাম | Android/Windows | বাংলাদেশ সময় | কী করেছেন | কী দেখেছেন | pass/fail। Push-এর screenshot এবং tap-এর ফল রাখুন। প্রতিদিন বাস্তব ব্যবহারে missed reminder/duplicate/ভুল task link লিখে রাখাই pilot; ১৪–৩০ দিন পরে তার ফল মূল্যায়ন হবে। পরীক্ষা শেষে শুধু TEST কাজগুলো যথাযথভাবে বন্ধ করুন।
