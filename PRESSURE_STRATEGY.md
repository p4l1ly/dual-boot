# Strategic Pressure Campaign for Intel Linux Driver

## Why GitHub > Email

You're right that email isn't optimal:
- ❌ Goes into support queue
- ❌ No visibility
- ❌ No community pressure
- ❌ Easy to ignore

**Better strategy**: Multi-channel PUBLIC pressure

## The Campaign

### 1. GitHub Issue #26 Comment (PRIMARY - Do This First)

**Why it's powerful**:
- ✅ Public visibility
- ✅ Intel engineers watch their repos
- ✅ Other users can upvote/support
- ✅ Creates historical record
- ✅ Shows up in searches

**What to post**:

```markdown
## Found Intel's Windows Drivers - 5 Months Old, Still No Linux Port

I've located Intel's Windows drivers that solve this issue:

### Windows Drivers (May 2024)
- **UsbBridge.sys** v4.0.1.346 (May 9, 2024)
  - Supports USB\VID_2AC1&PID_20C9 (Lattice NX33)
  - Provides USB-GPIO bridge functionality
  
- **UsbGpio.sys** v1.0.2.733 (May 8, 2024)  
  - Supports ACPI\INTC10B5 (Lunar Lake)
  - Provides platform GPIO interface

Both drivers are in `C:\Windows\System32\DriverStore\FileRepository\` on dual-boot systems.

### What This Proves

Intel **already supports this hardware** on Windows. This is not experimental or 
OEM-specific hardware - it's official Intel platform support.

The drivers have existed for **5 months** (May → October 2025) with no Linux port.

### Community POC

I've created a proof-of-concept Linux port (70% complete) based on binary analysis:
- USB driver successfully detects Lattice NX33
- GPIO chip registers (gpiochip5, 10 pins)
- Platform driver binds to INTC10B5
- Remaining: INT3472 integration (30% work)

This proves Linux support is **technically feasible** - just needs Intel to finish it.

### Request

@intel Can you please:
1. Port these drivers to Linux (you already have the code)
2. Provide timeline for Linux support, or
3. Provide technical guidance for community development

Multiple users are affected (this issue + others on forums). We've proven it's 
feasible. Please prioritize this.

**Hardware**: Dell XPS 13 9350, Lunar Lake  
**Windows**: Fully working
**Linux**: Waiting 5 months for driver port
```

### 2. File Linux Kernel Bugzilla (OFFICIAL RECORD)

**URL**: https://bugzilla.kernel.org/

**Why it matters**:
- ✅ Official bug tracking
- ✅ Kernel developers monitor it
- ✅ Shows up in kernel planning
- ✅ Creates accountability

**What to file**:

```
Component: Platform Driver - x86
Summary: Missing Intel UsbGpio driver for INTC10B5 (Lunar Lake)

Description:
Intel Lunar Lake laptops use INTC10B5 virtual GPIO controller for camera 
power management. Driver exists for Windows (UsbGpio.sys + UsbBridge.sys 
since May 2024) but not Linux.

Affected: Dell XPS 13 9350, other Lunar Lake laptops
Error: "cannot find GPIO chip INTC10B5:00, deferring"
Impact: Webcam non-functional

Windows driver details:
- UsbBridge.sys v4.0.1.346 - USB driver for Lattice NX33 (VID 2AC1, PID 20C9)
- UsbGpio.sys v1.0.2.733 - Platform driver for ACPI\INTC10B5

Reference: https://github.com/intel/ipu7-drivers/issues/26

Attachments: dmesg output, ACPI tables, lsusb output
```

### 3. Post on Reddit (COMMUNITY VISIBILITY)

**Subreddits**:
- r/archlinux
- r/linuxhardware  
- r/dell
- r/linux

**Title**: "Dell XPS 13 9350 (Lunar Lake) Webcam - Intel Has Windows Driver for 5 Months, Still No Linux Port"

**Post**:
```markdown
Found Intel's Windows drivers for Lunar Lake webcam (UsbBridge.sys, UsbGpio.sys 
from May 2024) but they haven't ported to Linux yet.

I reverse-engineered and wrote 70% working Linux drivers as proof of concept.

Intel issue: https://github.com/intel/ipu7-drivers/issues/26

If you have Lunar Lake laptop with non-working webcam, please comment on the 
GitHub issue to show demand!

[Technical details...]
```

**Why this works**:
- Gets wider visibility
- Other Lunar Lake users can join
- Creates social pressure
- Journalists/bloggers might pick it up

### 4. Arch Wiki Update (DOCUMENTATION)

**Page**: https://wiki.archlinux.org/title/Dell_XPS_13

**Add section**:
```
=== XPS 13 9350 (2024) - Lunar Lake ===

==== Webcam ====
The integrated webcam (OV02C10 sensor) does not work as of October 2025 
due to missing INTC10B5 GPIO driver.

Intel provides Windows drivers (UsbBridge.sys, UsbGpio.sys) since May 2024 
but has not yet ported to Linux.

Status: https://github.com/intel/ipu7-drivers/issues/26

Workaround: Use external USB webcam.
```

**Why this matters**:
- Warns other buyers
- Creates searchable documentation
- Shows up in Google
- References the issue

### 5. Intel Community Forums (DIRECT VISIBILITY)

**URL**: https://community.intel.com/

**Post in**: Graphics & Display, Linux

**Title**: "Lunar Lake INTC10B5 GPIO Driver - Windows Support Since May, No Linux?"

**Why**:
- Intel employees monitor their forums
- More direct than support email
- Public accountability

### 6. Linux Kernel Mailing List (TECHNICAL COMMUNITY)

**To**: linux-gpio@vger.kernel.org
**CC**: linux-kernel@vger.kernel.org

**Subject**: RFC: Intel UsbGpio driver for Lunar Lake (INTC10B5)

```
Hello,

Intel Lunar Lake laptops use a USB-based virtual GPIO controller (INTC10B5) 
for camera power management, backed by a Lattice NX33 FPGA.

Intel provides Windows drivers since May 2024:
- UsbBridge.sys (USB driver for VID 2AC1, PID 20C9)
- UsbGpio.sys (Platform driver for ACPI\INTC10B5)

No Linux equivalent exists. This affects webcam functionality on Lunar Lake 
laptops (Dell XPS 13 9350, etc.).

I've created a proof-of-concept based on reverse engineering:
[link to code if you upload to GitHub]

Questions for the community:
1. Is Intel working on Linux port?
2. Should community complete the implementation?
3. Best approach for ACPI device → USB GPIO chip routing?

References:
- GitHub issue: https://github.com/intel/ipu7-drivers/issues/26
- Kernel bugzilla: [TBD]
```

**Why this is powerful**:
- Reaches kernel developers directly
- Someone might contribute
- Intel developers on the list
- Creates technical discussion

## Multi-Channel Strategy Timeline

### Week 1 (This Week)
- **Day 1**: GitHub comment with evidence
- **Day 2**: File kernel bugzilla
- **Day 3**: Post on r/archlinux and r/linuxhardware
- **Day 4**: Update Arch Wiki

### Week 2
- Post on Intel community forums
- If no response, email to linux-kernel mailing list

### Week 3+
- Monitor all channels
- Respond to questions
- Escalate if needed

## How to Create Maximum Pressure

### The Power of Numbers

**Get others involved**:
1. On GitHub #26: "If you're affected, please react with 👍"
2. On Reddit: "Upvote for visibility"
3. On mailing list: CC others who responded

**Current**: 2-3 affected users visible
**Goal**: Show 10+ users affected

### The Power of Evidence

**What makes your case strong**:
- ✅ Windows drivers exist (not asking for new development)
- ✅ 5 months overdue (showing negligence)
- ✅ Community POC exists (showing it's feasible)
- ✅ Multiple platforms affected (not isolated issue)
- ✅ Multiple users affected (not edge case)

### The Power of Options

**Frame it as**:
"Intel can either:
A) Port their existing drivers (1 week work)
B) Provide technical guidance for community port
C) Explain why they won't support Linux

Silence is not acceptable for platform component with Windows support."

## What NOT to Do

❌ **Don't be rude or demanding** - Stay professional
❌ **Don't spam** - One post per channel
❌ **Don't exaggerate** - Stick to facts
❌ **Don't threaten** - No "I'll never buy Intel again"

✅ **Do be firm but respectful**
✅ **Do provide evidence**
✅ **Do show community support**
✅ **Do offer to help**

## Tracking Success

### Metrics to Watch

- **GitHub issue reactions/comments**: Shows community support
- **Reddit upvotes**: Shows visibility
- **Intel response**: Any acknowledgment is progress
- **Kernel activity**: Any commits/patches
- **Timeline provided**: Even "6 months" is better than silence

### What Counts as Success

**Short term** (1 week):
- Intel acknowledges the issue
- Other users join the discussion
- Wider visibility achieved

**Medium term** (1 month):
- Intel provides timeline, OR
- Community developer picks it up, OR
- Workaround discovered

**Long term** (3-6 months):
- Official driver released, OR
- Community driver completed, OR
- Clear "won't fix" so you can move on

## Your Next Move

I recommend:

**Option A (Best)**: GitHub comment first, then wait a week
- Less effort (one post)
- If Intel responds, great!
- If not, escalate to other channels

**Option B (Maximum pressure)**: All channels in one week
- More work
- Maximum visibility
- Might annoy Intel
- But gets results faster

**Which approach do you prefer?**

Let me know and I'll help you draft the GitHub comment with all the evidence we found!
