import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../data/data_manager.dart';
import '../../utils/string_extensions.dart';
import '../../services/prayer_times_service.dart';
import '../../services/quran_service.dart';
import '../../services/favorites_service.dart';
import '../../models/favorite_item.dart';
import '../../sections/html_content_renderer.dart';
import '../../ui/calendar/hijri_calendar_screen.dart';
import '../../ui/qibla/qibla_screen.dart';
import '../../presentation/screens/istikhara_screen.dart';
import '../../main.dart'; // For AlDhakereenApp globals


class AboutSection extends StatelessWidget {
  const AboutSection({super.key});
  @override
  Widget build(BuildContext context) {
    final about = DataManager.getAbout();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                backgroundImage: about['developer_image'] != null &&
                        about['developer_image'].toString().isNotEmpty
                    ? (about['developer_image'].toString().startsWith('http')
                        ? NetworkImage(about['developer_image'].toString())
                        : (about['developer_image']
                                .toString()
                                .startsWith('data:image')
                            ? MemoryImage(base64Decode(about['developer_image']
                                .toString()
                                .split(',')
                                .last))
                            : AssetImage(about['developer_image'].toString())
                                as ImageProvider))
                    : null,
                child: (about['developer_image'] == null ||
                        about['developer_image'].toString().isEmpty)
                    ? Icon(
                        getMaterialIcon(
                          about['developer_icon']?.toString() ?? 'person',
                        ),
                        size: 60,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                about['developer_name']?.toString() ?? 'المطور',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              const Divider(),
              const SizedBox(height: 15),
              Linkify(
                onOpen: (link) async {
                  if (!await launchUrl(Uri.parse(link.url))) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not launch url')),
                    );
                  }
                },
                text: about['app_info']?.toString() ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.6),
                linkStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
              if (about['social_media'] != null &&
                  (about['social_media'] as List).isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 15,
                  runSpacing: 15,
                  alignment: WrapAlignment.center,
                  children: (about['social_media'] as List).map((social) {
                    Widget iconWidget = const Icon(Icons.link, size: 30);
                    String iconName =
                        social['icon']?.toString().toLowerCase() ?? '';
                    if (iconName.contains('facebook'))
                      iconWidget =
                          const FaIcon(FontAwesomeIcons.facebook, size: 30);
                    else if (iconName.contains('twitter') ||
                        iconName.contains('x'))
                      iconWidget =
                          const FaIcon(FontAwesomeIcons.xTwitter, size: 30);
                    else if (iconName.contains('instagram'))
                      iconWidget =
                          const FaIcon(FontAwesomeIcons.instagram, size: 30);
                    else if (iconName.contains('youtube'))
                      iconWidget =
                          const FaIcon(FontAwesomeIcons.youtube, size: 30);
                    else if (iconName.contains('tiktok'))
                      iconWidget =
                          const FaIcon(FontAwesomeIcons.tiktok, size: 30);
                    else if (iconName.contains('telegram'))
                      iconWidget =
                          const FaIcon(FontAwesomeIcons.telegram, size: 30);
                    else if (iconName.contains('whatsapp'))
                      iconWidget =
                          const FaIcon(FontAwesomeIcons.whatsapp, size: 30);
                    else if (iconName.contains('snapchat'))
                      iconWidget =
                          const FaIcon(FontAwesomeIcons.snapchat, size: 30);
                    else if (iconName.contains('linkedin'))
                      iconWidget =
                          const FaIcon(FontAwesomeIcons.linkedin, size: 30);
                    else if (iconName.contains('github'))
                      iconWidget =
                          const FaIcon(FontAwesomeIcons.github, size: 30);

                    return InkWell(
                      onTap: () async {
                        final url = social['url']?.toString();
                        if (url != null) {
                          final uri = Uri.tryParse(url);
                          if (uri != null) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                      child: IconTheme(
                        data: IconThemeData(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        child: iconWidget,
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 30),
              if (about['developer_page'] != null)
                ElevatedButton.icon(
                  onPressed: () {
                    final url = about['developer_page'].toString();
                    final uri = Uri.tryParse(url);
                    if (uri != null &&
                        (uri.scheme == 'http' || uri.scheme == 'https')) {
                      launchUrl(uri);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('رابط غير صالح أو غير آمن'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('زيارة الموقع الشخصي'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
