import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:epub_translate_meaning/core/di/injection.dart';
import 'package:epub_translate_meaning/core/services/tts_service.dart';
import 'package:epub_translate_meaning/core/theme/app_colors.dart';
import 'package:epub_translate_meaning/features/settings/domain/entities/user_settings.dart';
import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_state.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/pdf_to_epub_usecase.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<Map<String, String>> _availableVoices = [];
  bool _isVerifyingKey = false;

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
        const SizedBox(height: 16),
        _buildAutoImportSection(settings),
        const SizedBox(height: 24),
        _buildSectionTitle('Voice Settings'),
        _buildVoiceSelectors(settings),
        const SizedBox(height: 32),
        _buildSectionTitle('Subscription Tier'),
        _buildTierInfo(settings),
        const SizedBox(height: 16),
        _buildProActivationCard(settings),
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

  Widget _buildTierInfo(UserSettings settings) {
    Color tierColor = AppColors.textSecondary;
    String tierName = 'Starter (Free)';
    IconData tierIcon = Icons.star_border_rounded;

    switch (settings.tier) {
      case AppTier.starter:
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
    final geminiController = TextEditingController(text: settings.customGeminiKey ?? '');
    final groqController = TextEditingController(text: settings.customGroqKey ?? '');
    
    final currentService = settings.preferredProService; // 'Gemini' or 'Groq'

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
                  child: const Icon(Icons.vpn_key_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Pro Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose your high-accuracy conversion service:',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            
            // Service Selector
            Row(
              children: [
                _buildServiceChip('Gemini', currentService == 'Gemini'),
                const SizedBox(width: 12),
                _buildServiceChip('Groq', currentService == 'Groq'),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Key Field Based on Selection
            if (currentService == 'Gemini') ...[
               _buildKeyFieldWithVerify(
                title: 'Google AI Studio Key',
                hint: 'Enter Gemini API Key',
                controller: geminiController,
                onSave: (val) => context.read<SettingsCubit>().updateGeminiKey(val),
              ),
            ] else ...[
               _buildKeyFieldWithVerify(
                title: 'Groq Cloud Key',
                hint: 'Enter Groq API Key',
                controller: groqController,
                onSave: (val) => context.read<SettingsCubit>().updateGroqKey(val),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServiceChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => context.read<SettingsCubit>().updatePreferredProService(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildKeyFieldWithVerify({
    required String title,
    required String hint,
    required TextEditingController controller,
    required Function(String) onSave,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isVerifyingKey ? null : () async {
              if (controller.text.isNotEmpty) {
                setState(() => _isVerifyingKey = true);
                try {
                  await onSave(controller.text);
                  final isWorking = await getIt<PdfToEpubUseCase>().checkApiStatus();
                  
                  if (isWorking && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API Key verified and saved!'), backgroundColor: AppColors.success),
                    );
                  } else if (!isWorking) {
                    throw Exception('API verified but test request failed.');
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Verification failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isVerifyingKey = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isVerifyingKey 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Verify and Save Key', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: const Icon(Icons.star_rounded, color: AppColors.secondary, size: 28),
        ),
        title: const Text('Elite Activated', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        subtitle: const Text('Unlimited translations with premium models', style: TextStyle(color: Colors.white70)),
        trailing: OutlinedButton(
          onPressed: () {
            context.read<SettingsCubit>().updateOpenAIKey('');
            context.read<SettingsCubit>().updateClaudeKey('');
          },
          child: const Text('Remove'),
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
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.secondary),
              SizedBox(width: 8),
              Text('Elite Tier APIs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          _buildApiKeyField(
            title: 'OpenAI API Key',
            subtitle: 'For GPT-4o models',
            icon: Icons.chat_bubble_outline,
            color: Colors.greenAccent,
            value: settings.customOpenAIKey,
            onChanged: (val) => context.read<SettingsCubit>().updateOpenAIKey(val),
          ),
          const SizedBox(height: 16),
          _buildApiKeyField(
            title: 'Anthropic API Key',
            subtitle: 'For Claude 3.5 models',
            icon: Icons.psychology,
            color: Colors.orangeAccent,
            value: settings.customClaudeKey,
            onChanged: (val) => context.read<SettingsCubit>().updateClaudeKey(val),
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
        const Text('Preferred Model', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: DropdownButton<String>(
            isExpanded: true,
            value: settings.preferredEliteModel,
            dropdownColor: AppColors.surface,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
            underline: const SizedBox(),
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
            onChanged: (String? newValue) {
              if (newValue != null) context.read<SettingsCubit>().updatePreferredEliteModel(newValue);
            },
            items: const [
              DropdownMenuItem(value: 'gpt-4o', child: Text('OpenAI GPT-4o')),
              DropdownMenuItem(value: 'gpt-4o-mini', child: Text('OpenAI GPT-4o-mini')),
              DropdownMenuItem(value: 'claude-3-5-sonnet-20240620', child: Text('Claude 3.5 Sonnet')),
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
        Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))]),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value?.length ?? 0),
          obscureText: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Paste key here...',
            filled: true,
            fillColor: Colors.black12,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoImportSection(UserSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              if (settings.autoImportFolderPaths.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_off_rounded,
                        size: 48,
                        color: AppColors.textMuted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No auto-import folders configured',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: settings.autoImportFolderPaths.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.05),
                    indent: 64,
                  ),
                  itemBuilder: (context, index) {
                    final path = settings.autoImportFolderPaths[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.folder_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        path.split(Platform.pathSeparator).last,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () => context.read<SettingsCubit>().removeAutoImportFolder(path),
                      ),
                    );
                  },
                ),
              
              // Add Folder Button
              InkWell(
                onTap: () async {
                  String? result = await FilePicker.platform.getDirectoryPath();
                  if (result != null && mounted) {
                    context.read<SettingsCubit>().addAutoImportFolder(result);
                  }
                },
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Add Import Folder',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
