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

// 2. Add Report Button in Actions
const marker = "child: const Icon(Icons.share_outlined, color: MiloColors.textPrimary, size: 18),\n                  ),\n                  onPressed: () {";

const endMarker = "},\n                ),\n                const SizedBox(width: 8),";

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

if (c.includes(endMarker)) {
  c = c.replace(endMarker, '},\n                ),' + reportBtn + '\n                const SizedBox(width: 8),');
  fs.writeFileSync(targetFile, c, 'utf8');
  console.log('SUCCESS: Injected Report Event icon button');
} else {
  console.log('End marker not found in event_details_screen.dart');
}
