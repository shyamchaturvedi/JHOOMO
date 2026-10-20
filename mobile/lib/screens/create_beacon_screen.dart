import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';

class CreateBeaconScreen extends StatefulWidget {
  const CreateBeaconScreen({super.key});

  @override
  State<CreateBeaconScreen> createState() => _CreateBeaconScreenState();
}

class _CreateBeaconScreenState extends State<CreateBeaconScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController(text: 'Hazratganj Coffee Spot');
  final TextEditingController _mapsUrlController = TextEditingController();
  String _selectedDuration = '2 Hours';
  int _spots = 3;
  String _selectedActivity = '☕ Coffee & Chat';

  final List<String> _activities = [
    '🎓 College Study & Jam',
    '💻 Office Co-working',
    '💅 Kitty & High Tea',
    '🧘 Yoga & Wellness',
    '🎤 Standup & Open Mic',
    '☕ Coffee & Chat',
    '🪘 Dandiya Rehearsal',
    '🎲 Board Games',
    '🏸 Turf Badminton',
    '🍕 Foodie Walk',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiloColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Broadcast Hangout Beacon 📡', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.textPrimary, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MiloColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MiloColors.emerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MiloColors.emerald.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.radar, color: MiloColors.emerald, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Beacons broadcast a temporary meetup signal to nearby verified users without revealing your exact coordinates.',
                    style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text('What are you planning?', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: MiloColors.textSecondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: MiloColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MiloColors.glassBorder),
            ),
            child: TextField(
              controller: _titleController,
              style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Anyone up for Garba rehearsal & Chai tonight?',
                hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text('Select Activity Type', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: MiloColors.textSecondary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _activities.map((act) {
              final isSelected = _selectedActivity == act;
              return GestureDetector(
                onTap: () => setState(() => _selectedActivity = act),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? MiloColors.primary : MiloColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? MiloColors.primaryLight : MiloColors.glassBorder),
                  ),
                  child: Text(
                    act,
                    style: GoogleFonts.inter(color: isSelected ? MiloColors.bg : MiloColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Area / Location
          Text('Approximate Meetup Spot / Cafe', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: MiloColors.textSecondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: MiloColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MiloColors.glassBorder),
            ),
            child: TextField(
              controller: _locationController,
              style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                icon: const Icon(Icons.place_outlined, color: MiloColors.rose, size: 18),
                hintText: 'e.g. Third Wave Coffee, Indiranagar',
                hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Google Maps URL Field
          Text('Google Maps Location Link (Optional) 📍', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: MiloColors.textSecondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: MiloColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MiloColors.glassBorder),
            ),
            child: TextField(
              controller: _mapsUrlController,
              style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                icon: const Icon(Icons.map_rounded, color: MiloColors.primaryLight, size: 18),
                hintText: 'Paste Google Maps link for easy navigation',
                hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 30-Min Notification Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MiloColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: MiloColors.primaryLight, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Milo automatically notifies all accepted squad members 30 minutes before meetup with the Google Maps pin.',
                    style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Spots & Duration
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Spots Needed', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: MiloColors.textSecondary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: MiloColors.bgSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MiloColors.glassBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _spots,
                          dropdownColor: MiloColors.bgSurface,
                          icon: const Icon(Icons.arrow_drop_down, color: MiloColors.primaryLight),
                          isExpanded: true,
                          items: [1, 2, 3, 4, 5, 6].map((s) {
                            return DropdownMenuItem<int>(
                              value: s,
                              child: Text('$s Person(s)', style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _spots = val ?? 3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Beacon Lifespan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: MiloColors.textSecondary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: MiloColors.bgSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MiloColors.glassBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDuration,
                          dropdownColor: MiloColors.bgSurface,
                          icon: const Icon(Icons.arrow_drop_down, color: MiloColors.primaryLight),
                          isExpanded: true,
                          items: ['1 Hour', '2 Hours', '4 Hours'].map((d) {
                            return DropdownMenuItem<String>(
                              value: d,
                              child: Text(d, style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedDuration = val ?? '2 Hours'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MiloColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                shadowColor: MiloColors.primaryGlow,
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('📡 Live Hangout Beacon Broadcasted to nearby users!')),
                );
              },
              child: Text(
                'Broadcast Beacon Now 🚀',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.bg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
