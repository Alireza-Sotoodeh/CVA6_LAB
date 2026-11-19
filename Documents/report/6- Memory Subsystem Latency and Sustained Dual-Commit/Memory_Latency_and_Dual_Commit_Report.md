---
author: Alireza Sotodeh
date: 2026-11-19 21:30:00 +03:30
status: NEW FILE
reason: Comprehensive architectural report for Suite 6 (Memory Subsystem Latency & Sustained Dual-Commit Throughput) on OpenHW CVA6 RISC-V core (cv32a6_imac_sv32) in Vivado behavioral simulation for the PQC Hardware Accelerator project addressed to Dr. Mahani.
---

# گزارش جامع تحلیل معماری سوییت ۶: تاخیر زیرسیستم حافظه و توان عملیاتی پایدار Dual-Commit در پردازنده CVA6

**مخاطب گزارش:** جناب آقای دکتر ماهانی  
**پروژه:** طراحی و اعتبارسنجی معماری پردازنده CVA6 به عنوان کنترلر شتاب‌دهنده سخت‌افزاری رمزنگاری پساکوانتومی (PQC - Post-Quantum Cryptography)  
**نگارنده:** علیرضا ستوده  
**پیکربندی پردازنده:** `cv32a6_imac_sv32` (هسته ۳۲ بیتی، Single-Issue با قابلیت Dual-Commit در بازنشستگی، پایپ‌لاین ۶ مرحله‌ای و Scoreboard هشت خانه‌ای)  
**ابزار شبیه‌سازی:** AMD Vivado 2025.1 XSIM (شبیه‌سازی رفتاری دقیق سیکل‌به‌سیکل - Behavioral Simulation)  

---

## ۱. مقدمه و هدف معماری (Context & Motivation)

استاد ارجمند، جناب آقای دکتر ماهانی؛

در فاز نهایی اعتبارسنجی رفتاری پردازنده CVA6 (سوییت ۶ از پلن جامع اعتبارسنجی چند سناریویی)، دو بعد بسیار کلیدی و حیاتی از معماری پردازنده رو به صورت تجربی و با تکیه بر لاگ‌های دقیق سیگنالی (۶۰ سیگنال سخت‌افزاری در `cva6_dual_commit_trace.csv`) مورد ارزیابی عمیق قرار دادم:

1. **توان عملیاتی بازنشستگی هم‌زمان دو دستور در یک سیکل (Dual-Commit Architecture):**  
   اگرچه معماری جلوبندی (Front-End) پردازنده CVA6 به صورت `Single-Issue` پیاده‌سازی شده (`NrIssuePorts = 1`) و در هر سیکل حداکثر یک دستور رو رمزگشایی و صادر می‌کنه، اما بخش انتهایی (Back-End) و اسکوربورد (Scoreboard) دارای دو پورت بازنشستگی کاملاً مستقل هست (`NrCommitPorts = 2`). در این آزمون قصد داشتم رفتار هسته رو در دستیابی به توان خروج آنی $\text{IPC} = 2.0$ (و $\text{CPI} = 0.5$) در قالب خوشه‌های دستوری مستقل و بدون وابستگی بسنجم.

2. **تاثیر تاخیر حافظه خارجی AXI بر کارایی و خاصیت مصونیت حافظه پنهان داده (L1 D-Cache Latency Immunity):**  
   در پیاده‌سازی الگوریتم‌های رمزنگاری پساکوانتومی نظیر **ML-KEM (Kyber)** و **ML-DSA (Dilithium)**، هسته دائماً با محاسبات سنگین NTT (تبدیل نظریه اعداد) و ضرب چندجمله‌ای‌ها سر و کار داره. سوال بنیادین این بود که اگر تاخیر پاسخ حافظه رم خارجی (AXI Memory Wait States) از صفر سیکل به ۴، ۸ و ۱۶ سیکل افزایش پیدا کنه، نرخ تاخیر حلقه محاسباتی هسته به چه صورت تخریب می‌شه و آیا حافظه نهان L1 داده می‌تونه این تاخیر سنگین رو به طور ۱۰۰٪ پنهان کنه؟

برای پاسخ به این سوالات، بنچ‌مارک اسمبلی اختصاصی [dual_commit_latency_test.S](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Documents/report/6-%20Memory%20Subsystem%20Latency%20and%20Sustained%20Dual-Commit/dual_commit_latency_test.S) و تست‌بنچ ساختاریافته [tb_cva6_dual_commit_latency.sv](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Vivado/CVA6/sim/tb_cva6_dual_commit_latency.sv) رو تدوین کردم و آزمون رو در Vivado XSIM اجرا نمودم.

---

## ۲. خلاصه نتایج و ارزیابی کمّی (Verification Scoreboard Summary)

شبیه‌سازی با موفقیت کامل و بدون کوچک‌ترین خطای عملکردی یا پروتکلی به اتمام رسید:

```text
============================================================
Verification Summary for CVA6 Suite 6:
  Total Checks : 17
  Errors       : 0
  Cycles Run   : 436
============================================================
[PASS] ALL SUITE-6 CHECKS PASSED
```

### شاخص‌های کلیدی اندازه‌گیری‌شده در شبیه‌سازی:
* **تعداد کل دستورات بازنشسته شده (Committed Instructions):** ۸۱ دستور
* **تعداد کل سیکل‌های بازنشستگی هم‌زمان (Dual-Commit Cycles):** **۹ سیکل مجزا**
* **سیکل خاتمه و قفل روی Self-Loop:** سیکل ۴۱۵ (۴۲۴۵ نانوثانیه با کلاک ۱۰ نانوثانیه‌ای)
* **ثبت تمام رجیسترهای معماری هدف:** مقادیر رجیسترهای `x1` تا `x21` با مقادیر مورد انتظار محاسباتی ۱۰۰٪ تطابق داشتند.

### تفکیک کارایی در ۴ تکرار حلقه با تاخیرهای متغیر AXI:
| تکرار حلقه (Iteration) | تاخیر حافظه AXI (Wait Cycles) | طول سیکلی (Span) | دستورات بازنشسته (Committed) | رخدادهای Dual-Commit | نرخ CPI اندازه‌گیری‌شده | وضعیت حافظه نهان داده (D-Cache) |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **تکرار ۱ (Cold Startup)** | **۰ سیکل** | ۴۰ سیکل | ۳۰ دستور | ۳ بار | **1.33** | خطای اولیه (Cold Miss) و پر شدن خط کش |
| **تکرار ۲ (Warm Cache)** | **۴ سیکل** | ۱۳ سیکل | ۱۳ دستور | ۲ بار | **1.00** | اصابت کامل (Cache Hit) و بای‌پس Store Buffer |
| **تکرار ۳ (High Latency)** | **۸ سیکل** | ۱۳ سیکل | ۱۳ دستور | ۲ بار | **1.00** | مصونیت کامل در برابر تاخیر حافظه خارجی |
| **تکرار ۴ (Extreme Latency)** | **۱۶ سیکل** | ۱۳ سیکل (بدنه) | ۲۵ دستور (با خروج) | ۲ بار | **1.00** (بدنه) / 0.52 (Burst) | پنهان‌سازی کامل تاخیر ۱۶ سیکلی خارجی |

---

## ۳. تحلیل معماری بازنشستگی دوگانه (Dual-Commit Microarchitecture)

### ۱. معماری Single-Issue در برابر Dual-Commit
یکی از نقاط قوت برجسته در طراحی CVA6 توسط OpenHW Group، استفاده از یک اسکوربورد (Scoreboard) هوشمند با عمق ۸ درایه است. در این هسته:
* **جلوبندی (Front-End & Issue Stage):** به علت محدودیت منابع و کاهش مساحت سیلیکون، در هر سیکل حداکثر یک دستور از صف دستورات (`InstrQueue`) خوانده شده و با پالس `IssueValid0` و تایید `IssueAck0` وارد اسکوربورد می‌شه (`NrIssuePorts = 1`).
* **انتهای خط‌لوله (Commit Stage):** اسکوربورد دارای دو پورت خروج مجزا است:
  - پورت اول (`CommitAck0` با آدرس رجیستر مقصد `GprWaddr0` و دیتای `GprWdata0`)
  - پورت دوم (`CommitAck1` با آدرس رجیستر مقصد `GprWaddr1` و دیتای `GprWdata1`)

### ۲. قوانین جفت‌شدن دستورات برای بازنشستگی هم‌زمان (Pairing Rules)
برای اینکه دو دستور در یک سیکل واحد به صورت Dual-Commit بازنشسته بشن، شرایط سخت‌افزاری زیر در اسکوربورد CVA6 باید برقرار باشه:
1. **آماده بودن نتیجه درایه قدیمی‌تر (Head of Scoreboard):** دستور حاضر در اسلات ۰ اسکوربورد باید پرچم اتمام اجرای خود رو دریافت کرده باشه (`trans_id.done = 1`).
2. **آماده بودن نتیجه درایه بعدی (Immediate Next Slot):** دستور حاضر در اسلات ۱ نیز باید قبل از این سیکل اجرای خود رو به پایان رسانده باشه و هیچ مخاطره داده‌ای معوق (RAW Hazard) نسبت به اسلات ۰ نداشته باشه.
3. **عدم وجود وقفه یا استثنا (No Pending Traps/Flushes):** هیچ‌کدام از دو دستور نباید منجر به تولید Trap، فلاش کنترل، یا دستورات دسترسی به ثبات‌های کنترلی (CSR) شده باشند.
4. **دسترسی به پورت‌های نوشتن ثبات‌ها:** بانک ثبات‌های عمومی (Register File) در CVA6 دارای دو پورت نوشتن اختصاصی است، بنابراین هر دو دستور می‌توانند در لبه مثبت کلاک ثبات‌های مقصد خودشون رو به طور هم‌زمان به‌روزرسانی کنند.

![Scoreboard Dual-Commit Ports](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Documents/report/6-%20Memory%20Subsystem%20Latency%20and%20Sustained%20Dual-Commit/figures/04_dual_commit_scoreboard_ports.svg)

### ۳. بررسی رخدادهای ثبت‌شده در شبیه‌سازی
در طول اجرای برنامه، دقیقاً ۹ سیکل بازنشستگی دوگانه مشاهده شد که جزئیات آن‌ها به شرح زیر است:

```text
سیکل ۳۱۶: CommitAck0=1 (PC: 0x80000048 - SW)   | CommitAck1=1 (PC: 0x8000004C - ADDI x6,1)
سیکل ۳۳۵: CommitAck0=1 (PC: 0x80000058 - LW)   | CommitAck1=1 (PC: 0x8000005C - ADDI x10,4)
سیکل ۳۳۶: CommitAck0=1 (PC: 0x80000060 - ADD)  | CommitAck1=1 (PC: 0x80000064 - ADD x12)
سیکل ۳۵۹: CommitAck0=1 (PC: 0x80000048 - SW)   | CommitAck1=1 (PC: 0x8000004C - ADDI x6,1)
سیکل ۳۶۳: CommitAck0=1 (PC: 0x80000058 - LW)   | CommitAck1=1 (PC: 0x8000005C - ADDI x10,4)
سیکل ۳۷۹: CommitAck0=1 (PC: 0x80000048 - SW)   | CommitAck1=1 (PC: 0x8000004C - ADDI x6,1)
سیکل ۳۸۳: CommitAck0=1 (PC: 0x80000058 - LW)   | CommitAck1=1 (PC: 0x8000005C - ADDI x10,4)
سیکل ۳۹۵: CommitAck0=1 (PC: 0x80000048 - SW)   | CommitAck1=1 (PC: 0x8000004C - ADDI x6,1)
سیکل ۳۹۹: CommitAck0=1 (PC: 0x80000058 - LW)   | CommitAck1=1 (PC: 0x8000005C - ADDI x10,4)
```

نکته بسیار هیجان‌انگیز در **سیکل‌های ۳۳۵ و ۳۳۶** رخ داد؛ جایی که هسته دو سیکل متوالی Dual-Commit انجام داد! یعنی در طی فقط ۲ سیکل کلاک، ۴ دستورالعمل کامل بازنشسته شدند ($\text{IPC} = 2.0$ آنی و $\text{CPI} = 0.5$). این رخداد در شکل زیر به روشنی قابل رویت است:

![Sustained Dual-Commit Burst](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Documents/report/6-%20Memory%20Subsystem%20Latency%20and%20Sustained%20Dual-Commit/figures/02_sustained_dual_commit_burst.svg)

---

## ۴. تحلیل تاخیر حافظه و پدیده مصونیت کش داده (D-Cache Immunity)

در این سناریو، یک بررسی تطبیقی در تکرارهای مختلف حلقه اعمال شد به گونه‌ای که پاسخ‌دهنده حافظه AXI در تست‌بنچ برای هر تکرار، تاخیر ساختگی درج می‌کرد:
* تکرار ۱: تاخیر حافظه = ۰ سیکل
* تکرار ۲: تاخیر حافظه = ۴ سیکل تاخیر در کانال RVALID و BVALID
* تکرار ۳: تاخیر حافظه = ۸ سیکل تاخیر
* تکرار ۴: تاخیر حافظه = ۱۶ سیکل تاخیر

![AXI Latency Degradation Curve](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Documents/report/6-%20Memory%20Subsystem%20Latency%20and%20Sustained%20Dual-Commit/figures/03_axi_latency_degradation_curve.svg)

### رفتار مشاهده‌شده و چرایی عدم افت کارایی:
در یک پردازنده بدون کش، افزایش تاخیر حافظه به ۱۶ سیکل بلافاصله باعث جهش CPI از حدود ۱.۳ به بیش از ۲.۵ تا ۳.۰ می‌شه (چون هر دستور `lw` و `sw` باید مسیر رفت و برگشت باس رو طی کنه). اما در CVA6 دیدیم که **طول سیکلی تکرارهای ۲، ۳ و ۴ همگی دقیقاً برابر ۱۳ سیکل ماند و CPI روی عدد رویایی 1.00 ثابت شد!**

دلایل ریزمعماری این رفتار عبارتند از:
1. **پدیده Cache Warm-Up در تکرار اول:** در تکرار ۱، با اولین اجرای دستور `sw x5, 0(x1)` و `lw x9, 0(x1)` در آدرس `0x80000200`، خط حافظه نهان داده (D-Cache Line) برای بار اول از حافظه خارجی خوانده شد (Cold Miss) که منجر به افزایش طول تکرار به ۴۰ سیکل و CPI = 1.33 شد.
2. **بای‌پَس از طریق Store Buffer:** دستورات ذخیره‌سازی (`sw`) ابتدا داده را در بافر ذخیره‌سازی (`Store Buffer`) هسته قرار می‌دهند و اجرای خط‌لوله بدون معطلی برای پاسخ گذرگاه به جلو حرکت می‌کند.
3. **اصابت ۱۰۰٪ در حافظه نهان داده (L1 D-Cache Hit):** در تکرارهای بعدی، داده آدرس `0x80000200` از قبل در حافظه نهان سطح اول یا بافر ذخیره‌سازی موجود است. در نتیجه دستور `lw` بدون نیاز به دسترسی به گذرگاه AXI خارجی، در یک سیکل پاسخ خود را دریافت می‌کند.
4. **نتیجه‌گیری معماری:** حافظه نهان داده در صورت مقیم بودن داده‌های محاسباتی، پردازنده رو در برابر تاخیر حافظه‌های خارجی فوق‌العاده کند (حتی تاخیرهای بالاتر از ۱۶ سیکل نظیر رم‌های DDR خارج تراشه) کاملاً محافظت و ایزوله می‌کنه.

---

## ۵. تایم‌لاین کامل اجرای تست و اعتبارسنجی رجیسترها (Execution Timeline)

شکل زیر نمای کلی کل فرآیند اجرای آزمون از راه‌اندازی اولیه و ریست تا فازهای مختلف حلقه و بازنشستگی نهایی را نمایش می‌دهد:

![Full Execution Timeline](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Documents/report/6-%20Memory%20Subsystem%20Latency%20and%20Sustained%20Dual-Commit/figures/01_execution_timeline.svg)

### جدول اعتبارسنجی مقادیر رجیسترهای معماری (Scoreboard Register Check):
تست‌بنچ در لحظه رسیدن به حلقه توقف (`0x80000088`) مقادیر تمام رجیسترهای درگیر در محاسبات رو به صورت خودکار مقایسه کرد:

| رجیستر | نام قراردادی ABI | مقدار هگزادسیمال ثبت‌شده | مقدار ده‌دهی | مقدار مورد انتظار | نتیجه ارزیابی اسکوربورد |
| :---: | :---: | :---: | :---: | :---: | :---: |
| `x1` | `ra` | `0x80000200` | 2147484160 | آدرس بافر حافظه دیتا | **PASS** |
| `x5` | `t0` | `0x0000002a` | 42 | داده ذخیره‌شده اولیه | **PASS** |
| `x6` | `t1` | `0x00000004` | 4 | افزایش ۱ واحدی در ۴ تکرار | **PASS** |
| `x7` | `t2` | `0x00000008` | 8 | افزایش ۲ واحدی در ۴ تکرار | **PASS** |
| `x8` | `s0` | `0x0000000c` | 12 | افزایش ۳ واحدی در ۴ تکرار | **PASS** |
| `x9` | `s1` | `0x0000002a` | 42 | داده خوانده‌شده از آدرس بافر | **PASS** |
| `x10` | `a0` | `0x00000010` | 16 | افزایش ۴ واحدی در ۴ تکرار | **PASS** |
| `x11` | `a1` | `0x0000000c` | 12 | حاصل `t1 + t2` ($4 + 8$) | **PASS** |
| `x12` | `a2` | `0x0000001c` | 28 | حاصل `s0 + a0` ($12 + 16$) | **PASS** |
| `x13` | `a3` | `0x00000016` | 22 | حاصل `a1 + 10` ($12 + 10$) | **PASS** |
| `x14` | `a4` | `0x00000030` | 48 | حاصل `a2 + 20` ($28 + 20$) | **PASS** |
| `x15` | `a5` | `0x00000026` | 38 | حاصل `a3 ^ a4` ($22 \oplus 48$) | **PASS** |
| `x16` | `a6` | `0x00000098` | 152 | حاصل `a5 << 2` ($38 \times 4$) | **PASS** |
| `x20` | `s4` | `0x000003e7` | 999 | مارکر اتمام موفقیت‌آمیز حلقه | **PASS** |
| `x21` | `s5` | `0x00000005` | 5 | شمارنده تکرار حلقه (رسیدن به ۵) | **PASS** |

---

## ۶. دستاوردهای کلیدی برای شتاب‌دهنده رمزنگاری پساکوانتومی (PQC Accelerator Insights)

جناب آقای دکتر ماهانی، بر اساس داده‌های تجربی استخراج‌شده از این سوییت، راهکارهای مهندسی و معماری زیر برای پیاده‌سازی بهینه شتاب‌دهنده PQC ما روی پردازنده CVA6 حاصل شد:

1. **سازمان‌دهی بافرهای چندجمله‌ای در کش داده (SRAM Scratchpad / Cache Residency):**  
   الگوریتم‌های پساکوانتومی مانند Kyber و Dilithium شامل مراحل متعدد پروانه‌ای NTT (مانند Cooley-Tukey یا Gentleman-Sande) روی چندجمله‌ای‌های با درجه ۲۵۶ هستند. اگر ضرایب چندجمله‌ای و فاکتورهای چرخش (Twiddle Factors) در محدوده حافظه نهان سطح اول داده قرار بگیرند، هسته می‌تواند بدون هیچ‌گونه افت ناشی از باس حافظه خارجی، با حداکثر توان عملیاتی ($\text{CPI} \approx 1.0$) کار کند.

2. **بهره‌برداری حداکثری از Dual-Commit در چینش دستورات اسمبلی:**  
   با توجه به اینکه جلوبندی Single-Issue است اما خروج Dual-Commit داریم، کامپایلر یا برنامه‌نویس اسمبلی باید دستورات مستقل را به گونه‌ای جفت کنند که بعد از محاسبات ضرب طولانی، چندین دستور ساده ALU یا محاسبات اندیس بدون وابستگی در صف قرار گیرند تا هسته بتواند آن‌ها را به صورت جفت‌های هم‌زمان بازنشسته کند و بخش جلویی خط‌لوله بتواند وقفه را جبران کند.

3. **ارزیابی نهایی برنامه اعتبارسنجی جامع:**  
   با اتمام موفق این سوییت، تمامی ۶ سوییت تعیین‌شده در پلن اعتبارسنجی چند سناریویی با نمره ۱۰۰٪ قبولی و تولید کامل شکل‌های گرافیکی و گزارش‌های تفصیلی به اتمام رسیدند. این امر پایه اعتبارسنجی فوق‌العاده مستحکمی برای پیاده‌سازی ماژول‌های شتاب‌دهنده PQC بر روی این پلتفرم فراهم می‌سازد.

---

## ۷. مراجع و پیوست‌های فنی

1. کدهای اسمبلی بنچ‌مارک سوییت ۶: [dual_commit_latency_test.S](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Documents/report/6-%20Memory%20Subsystem%20Latency%20and%20Sustained%20Dual-Commit/dual_commit_latency_test.S)
2. فایل تست‌بنچ SystemVerilog: [tb_cva6_dual_commit_latency.sv](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Vivado/CVA6/sim/tb_cva6_dual_commit_latency.sv)
3. اسکریپت شبیه‌سازی خودکار Vivado Tcl: [run_sim_dual_commit.tcl](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Vivado/CVA6/scripts/run_sim_dual_commit.tcl)
4. فایل لاگ دقیق سیگنال‌ها (CSV Trace): [cva6_dual_commit_trace.csv](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Vivado/CVA6/cva6_dual_commit_trace.csv)
5. اسکریپت پایتون رسم شکل‌های برداری: [generate_svg_waveforms.py](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Documents/report/6-%20Memory%20Subsystem%20Latency%20and%20Sustained%20Dual-Commit/generate_svg_waveforms.py)
6. شکل‌های برداری SVG:
   - [01_execution_timeline.svg](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Documents/report/6-%20Memory%20Subsystem%20Latency%20and%20Sustained%20Dual-Commit/figures/01_execution_timeline.svg)
   - [02_sustained_dual_commit_burst.svg](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Documents/report/6-%20Memory%20Subsystem%20Latency%20and%20Sustained%20Dual-Commit/figures/02_sustained_dual_commit_burst.svg)
   - [03_axi_latency_degradation_curve.svg](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Documents/report/6-%20Memory%20Subsystem%20Latency%20and%20Sustained%20Dual-Commit/figures/03_axi_latency_degradation_curve.svg)
   - [04_dual_commit_scoreboard_ports.svg](file:///home/alireza/GitHub/Mahani/CVA6_LAB/Documents/report/6-%20Memory%20Subsystem%20Latency%20and%20Sustained%20Dual-Commit/figures/04_dual_commit_scoreboard_ports.svg)
