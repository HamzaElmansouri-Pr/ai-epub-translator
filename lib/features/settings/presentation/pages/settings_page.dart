import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:epub_translate_meaning/core/di/injection.dart';
import 'package:epub_translate_meaning/core/services/tts_service.dart';
import 'package:epub_translate_meaning/core/theme/app_colors.dart';
import 'package:epub_translate_meaning/features/settings/domain/entities/user_settings.dart';
import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<Map<String, String>> _availableVoices = [];

  @override
  void initState() {
    super.initState();
    context.read<SettingsCubit>().loadSettings();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final voices = await getIt<TtsService>().getVoices();
    if (mounted) {
      setState(() {
        _availableVoices = voices;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          if (state is SettingsLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          } else if (state is SettingsLoaded) {
            return _buildSettingsList(state.settings);
          } else if (state is SettingsError) {
            return Center(
              child: Text(
                state.message,
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSettingsList(UserSettings settings) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildSectionTitle('General configuration'),
        _buildLanguageSelector(settings),
        const SizedBox(height: 24),
        _buildSectionTitle('Voice Settings'),
        _buildVoiceSelectors(settings),
        const SizedBox(height: 32),
        _buildSectionTitle('Subscription Tier'),
        _buildTierInfo(settings),
        const SizedBox(height: 16),
        if (settings.tier == AppTier.starter) _buildProActivationCard(settings),
        if (settings.tier == AppTier.pro) _buildProStatusCard(settings),
        if (settings.tier == AppTier.elite) _buildEliteStatusCard(settings),
        const SizedBox(height: 32),
        _buildSectionTitle('Premium Features'),
        _buildEliteFeatures(settings),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary.withValues(alpha: 0.8),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(UserSettings settings) {
    final languages = [
      'Arabic',
      'English',
      'French',
      'Spanish',
      'German',
      'Turkish',
      'Chinese',
      'Japanese',
      'Korean',
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: const Text(
          'Target Language',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          'Current: ${settings.targetLanguage}',
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.8),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: languages.contains(settings.targetLanguage)
                ? settings.targetLanguage
                : 'Arabic',
            dropdownColor: AppColors.surface,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary,
            ),
            underline: const SizedBox(),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            onChanged: (String? newValue) {
              if (newValue != null) {
                context.read<SettingsCubit>().updateLanguage(newValue);
              }
            },
            items: languages.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceSelectors(UserSettings settings) {
    if (_availableVoices.isEmpty) {
      return const Center(child: Text('Loading voices...'));
    }
    
    // Sort voices to show Arabic first if we want
    final sortedVoices = List<Map<String, String>>.from(_availableVoices);
    sortedVoices.sort((a, b) {
      final aIsAr = (a['locale'] ?? '').toLowerCase().startsWith('ar');
      final bIsAr = (b['locale'] ?? '').toLowerCase().startsWith('ar');
      if (aIsAr && !bIsAr) return -1;
      if (!aIsAr && bIsAr) return 1;
      return (a['name'] ?? '').compareTo(b['name'] ?? '');
    });

    final voiceItems = sortedVoices.map((v) {
      final val = '${v['name']}||${v['locale']}';
      final disp = '${v['name']} (${v['locale']})';
      return DropdownMenuItem<String>(
        value: val,
        child: Text(disp, overflow: TextOverflow.ellipsis, maxLines: 1),
      );
    }).toList();

    // ensure current values are in list or fallback
    String? currentTtsVoice = settings.ttsVoice;
    if (currentTtsVoice != null && !voiceItems.any((e) => e.value == currentTtsVoice)) {
      currentTtsVoice = null;
    }
    String? currentBookVoice = settings.bookVoice;
    if (currentBookVoice != null && !voiceItems.any((e) => e.value == currentBookVoice)) {
      currentBookVoice = null;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text('TTS Voice (Translations)', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: DropdownButton<String>(
              isExpanded: true,
              value: currentTtsVoice,
              hint: const Text('Select a voice'),
              dropdownColor: AppColors.surface,
              underline: const SizedBox(),
              items: voiceItems,
              onChanged: (val) {
                if (val != null) context.read<SettingsCubit>().updateTtsVoice(val);
              },
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          ListTile(
            title: const Text('Audiobook Voice', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: DropdownButton<String>(
              isExpanded: true,
              value: currentBookVoice,
              hint: const Text('Select a voice'),
              dropdownColor: AppColors.surface,
              underline: const SizedBox(),
              items: voiceItems,
              onChanged: (val) {
                if (val != null) context.read<SettingsCubit>().updateBookVoice(val);
              },
            ),
          ),
        ],
      ),
    );
  }
        tierColor = AppColors.textSecondary;
        tierName = 'Starter (Free)';
        tierIcon = Icons.star_border_rounded;
        break;
      case AppTier.pro:
        tierColor = AppColors.primary;
        tierName = 'Pro (BYOK)';
        tierIcon = Icons.star_half_rounded;
        break;
      case AppTier.elite:
        tierColor = AppColors.secondary;
        tierName = 'Elite (Premium)';
        tierIcon = Icons.star_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tierColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(tierIcon, color: tierColor, size: 28),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Tier',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tierName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: tierColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProActivationCard(UserSettings settings) {
    final controller = TextEditingController(
      text: settings.customGeminiKey ?? '',
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.vpn_key_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Activate Pro',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Enter your Google AI Studio API key to get unlimited translations and bypass the daily limit.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter Gemini API Key',
                hintStyle: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    context.read<SettingsCubit>().updateGeminiKey(
                      controller.text,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                            ),
                            SizedBox(width: 12),
                            Text('API Key saved successfully!'),
                          ],
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Save Key',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEliteStatusCard(UserSettings settings) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.star_rounded,
            color: AppColors.secondary,
            size: 28,
          ),
        ),
        title: const Text(
          'Elite Activated',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Unlimited translations with premium models',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ),
        trailing: OutlinedButton(
          onPressed: () {
            context.read<SettingsCubit>().updateOpenAIKey('');
            context.read<SettingsCubit>().updateClaudeKey('');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Elite API Keys removed'),
                backgroundColor: AppColors.surface,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Remove Key',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildProStatusCard(UserSettings settings) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 28,
          ),
        ),
        title: const Text(
          'Pro Activated',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Using your personal API key',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ),
        trailing: OutlinedButton(
          onPressed: () {
            context.read<SettingsCubit>().updateGeminiKey('');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('API Key removed'),
                backgroundColor: AppColors.surface,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.error),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text(
            'Remove',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEliteFeatures(UserSettings settings) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Elite Tier APIs',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (settings.tier == AppTier.elite)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildApiKeyField(
            title: 'OpenAI API Key',
            subtitle: 'For GPT-4o models',
            icon: Icons.chat_bubble_outline,
            color: Colors.greenAccent,
            value: settings.customOpenAIKey,
            onChanged: (val) =>
                context.read<SettingsCubit>().updateOpenAIKey(val),
          ),
          const SizedBox(height: 16),
          _buildApiKeyField(
            title: 'Anthropic API Key',
            subtitle: 'For Claude 3.5 models',
            icon: Icons.psychology,
            color: Colors.orangeAccent,
            value: settings.customClaudeKey,
            onChanged: (val) =>
                context.read<SettingsCubit>().updateClaudeKey(val),
          ),
          if (settings.tier == AppTier.elite) ...[
            const SizedBox(height: 24),
            _buildEliteModelSelector(settings),
          ],
        ],
      ),
    );
  }

  Widget _buildEliteModelSelector(UserSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferred Model',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            value:
                [
                  'gpt-4o',
                  'gpt-4o-mini',
                  'claude-3-5-sonnet-20240620',
                ].contains(settings.preferredEliteModel)
                ? settings.preferredEliteModel
                : 'gpt-4o',
            dropdownColor: AppColors.surface,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary,
            ),
            underline: const SizedBox(),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            onChanged: (String? newValue) {
              if (newValue != null) {
                context.read<SettingsCubit>().updatePreferredEliteModel(
                  newValue,
                );
              }
            },
            items: const [
              DropdownMenuItem(value: 'gpt-4o', child: Text('OpenAI GPT-4o')),
              DropdownMenuItem(
                value: 'gpt-4o-mini',
                child: Text('OpenAI GPT-4o-mini'),
              ),
              DropdownMenuItem(
                value: 'claude-3-5-sonnet-20240620',
                child: Text('Claude 3.5 Sonnet'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApiKeyField({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String? value,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: value)
            ..selection = TextSelection.collapsed(offset: value?.length ?? 0),
          obscureText: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Paste your API key here...',
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            filled: true,
            fillColor: Colors.black12,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color.withValues(alpha: 0.5)),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
