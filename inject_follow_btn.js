const fs = require('fs');
const path = require('path');

const targetFile = path.resolve('mobile/lib/screens/community/single_community_hub_screen.dart');
let c = fs.readFileSync(targetFile, 'utf8');

// Target string inside post header
const target = '                      const SizedBox(height: 2),\n                      Text(post.timeAgo, style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted)),\n                    ],\n                  ),\n                ),\n              ],\n            ),';

const replacement = `                      const SizedBox(height: 2),
                      Text(post.timeAgo, style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted)),
                    ],
                  ),
                ),
                // Follow / Broadcast Action Button (Auto-Enrolls to 1-Way Broadcast Channel)
                if (post.authorRole == 'INFLUENCER' || post.authorRole == 'ORGANIZER')
                  GestureDetector(
                    onTap: () {
                      final isFollowing = _followedCreators.contains(post.authorName);
                      setState(() {
                        if (isFollowing) {
                          _followedCreators.remove(post.authorName);
                        } else {
                          _followedCreators.add(post.authorName);
                        }
                      });

                      final matchingEvent = MockData.events.firstWhere(
                        (e) => e.title == post.eventTag || e.id == post.eventId,
                        orElse: () => MockData.events.first,
                      );

                      if (!isFollowing) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF0F172A),
                            behavior: SnackBarBehavior.floating,
                            content: Row(
                              children: [
                                const Icon(Icons.campaign_rounded, color: Color(0xFFE11D48), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Joined \${post.authorName}'s Official Broadcast Channel! 📢",
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            action: SnackBarAction(
                              label: 'OPEN',
                              textColor: const Color(0xFFF43F5E),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UniversalBroadcastChannelScreen(
                                      type: post.authorRole == 'ORGANIZER' ? BroadcastType.eventOrganizer : BroadcastType.creatorChannel,
                                      channelTitle: '\${post.authorName} • Broadcast Hub',
                                      channelSubtitle: 'Official Real-time Broadcast Channel',
                                      ownerName: post.authorName,
                                      ownerHandle: post.socialHandle ?? '@\${post.authorName.toLowerCase().replaceAll(' ', '')}',
                                      ownerAvatar: post.authorAvatar,
                                      ownerUid: 'uid_\${post.id}',
                                      event: matchingEvent,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _followedCreators.contains(post.authorName)
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFFE11D48).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _followedCreators.contains(post.authorName)
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFFFDA4AF),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _followedCreators.contains(post.authorName)
                                ? Icons.campaign_rounded
                                : Icons.person_add_rounded,
                            size: 13,
                            color: _followedCreators.contains(post.authorName)
                                ? const Color(0xFF475569)
                                : const Color(0xFFE11D48),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _followedCreators.contains(post.authorName) ? 'Channel Joined' : 'Follow & Join',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _followedCreators.contains(post.authorName)
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFE11D48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),`;

// Standardize newlines before replacement
c = c.replace(/\r\n/g, '\n');
const normalizedTarget = target.replace(/\r\n/g, '\n');

if (c.includes(normalizedTarget)) {
  c = c.replace(normalizedTarget, replacement);
  fs.writeFileSync(targetFile, c, 'utf8');
  console.log('SUCCESS: Injected Follow & Join Broadcast button!');
} else {
  console.log('FAILED to find target in file');
}
