const fs = require('fs');
const path = require('path');

const targetFile = path.resolve('mobile/lib/screens/event_details_screen.dart');
let c = fs.readFileSync(targetFile, 'utf8').replace(/\r\n/g, '\n');

// 1. Add imports if missing
if (!c.includes('report_block_sheet.dart')) {
  c = c.replace(
    "import '../services/milo_session_service.dart';",
    "import '../services/milo_session_service.dart';\nimport '../widgets/report_block_sheet.dart';\nimport '../services/milo_moderation_service.dart';"
  );
}

// 2. Locate share button and insert report button
const marker = "child: const Icon(Icons.share_outlined, color: MiloColors.textPrimary, size: 18),";
const idx = c.indexOf(marker);

if (idx !== -1) {
  const closeBtn = c.indexOf('},\n            ),', idx);
  if (closeBtn !== -1) {
    const splitPoint = closeBtn + '},\n            ),'.length;
    const before = c.substring(0, splitPoint);
    const after = c.substring(splitPoint);

    const reportBtn = `
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MiloColors.bgSurface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag_outlined, color: Color(0xFFE11D48), size: 18),
              ),
              tooltip: 'Report Event',
              onPressed: () {
                ReportBlockSheet.show(
                  context,
                  targetUid: event.id,
                  targetName: event.title,
                  targetType: TargetType.event,
                  eventId: event.id,
                );
              },
            ),`;

    fs.writeFileSync(targetFile, before + reportBtn + after, 'utf8');
    console.log('SUCCESS: Spliced Report Event button into AppBar!');
  } else {
    console.log('Could not find closeBtn');
  }
} else {
  console.log('Marker not found');
}
