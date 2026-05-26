import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../providers/survey_provider.dart';
import '../models/survey.dart';
import '../services/ad_service.dart';

class SurveyScreen extends ConsumerStatefulWidget {
  final String surveyId;
  final String title;

  const SurveyScreen({super.key, required this.surveyId, required this.title});

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  int _currentIndex = 0;
  String? _selectedOption;
  bool _showReveal = false;
  bool _submitting = false;
  final List<Map<String, dynamic>> _answers = [];
  late int _startedAtMs;

  @override
  void initState() {
    super.initState();
    _startedAtMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _selectOption(String label, SurveyDetail survey) {
    if (_selectedOption != null) return;
    setState(() {
      _selectedOption = label;
      _answers.add({
        'question_id': survey.questions[_currentIndex].id,
        'selected_option': label,
        'answered_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _showReveal = true);
    });
  }

  void _next(SurveyDetail survey) {
    if (_currentIndex < survey.questions.length - 1) {
      final nextIndex = _currentIndex + 1;
      if (nextIndex % 5 == 0 && nextIndex < survey.questions.length) {
        _showAdThenAdvance(nextIndex);
        return;
      }
      setState(() {
        _currentIndex = nextIndex;
        _selectedOption = null;
        _showReveal = false;
      });
    } else {
      _completeSurvey(survey);
    }
  }

  Future<void> _showAdThenAdvance(int nextIndex) async {
    await AdService().showInterstitialAd(
      onDismissed: () {
        if (mounted) {
          setState(() {
            _currentIndex = nextIndex;
            _selectedOption = null;
            _showReveal = false;
          });
        }
      },
    );
  }

  Future<void> _completeSurvey(SurveyDetail survey) async {
    setState(() => _submitting = true);
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.completeSurvey(widget.surveyId, _answers, _startedAtMs);
      if (mounted) {
        ref.invalidate(surveysProvider);
        ref.read(userProvider.notifier).refresh();
        Navigator.pushReplacementNamed(context, '/results', arguments: {
          'completionId': result['completion_id'],
          'baseReward': result['base_reward'],
          'adMultiplier': result['ad_multiplier'],
          'premiumMultiplier': result['premium_multiplier'],
          'finalReward': result['final_reward'],
          'surveyTitle': survey.title,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.error));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final surveyAsync = ref.watch(surveyDetailProvider(widget.surveyId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 14)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitDialog(),
        ),
      ),
      body: surveyAsync.when(
        data: (survey) => Stack(
          children: [
            _buildQuestionView(survey),
            if (_submitting)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text('Calculating your reward...', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildQuestionView(SurveyDetail survey) {
    final question = survey.questions[_currentIndex];
    final progress = (_currentIndex + 1) / survey.questions.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Question ${_currentIndex + 1} of ${survey.questions.length}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(question.questionType.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.divider,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.questionText,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.3),
                ),
                const SizedBox(height: 24),
                ...question.options.map((opt) => _buildOptionButton(opt, question)),
                if (_showReveal && question.afterAnswerReveal != null) ...[
                  const SizedBox(height: 24),
                  _buildRevealCard(question.afterAnswerReveal!),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _next(survey),
                      child: Text(_currentIndex < survey.questions.length - 1 ? 'Next Question' : 'See Results'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionButton(QuestionOption option, SurveyQuestion question) {
    final isSelected = _selectedOption == option.label;
    final isAnswered = _selectedOption != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: isAnswered ? null : () => _selectOption(option.label, ref.read(surveyDetailProvider(widget.surveyId)).value!),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : isAnswered
                    ? Colors.grey.withValues(alpha: 0.05)
                    : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(option.label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.text,
                  style: TextStyle(
                    fontSize: 15,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevealCard(String text) {
    return AnimatedOpacity(
      opacity: _showReveal ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text('Did you know?', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.5)),
          ],
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Survey?'),
        content: const Text('Your progress will be lost and you won\'t earn any points.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Stay')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Leave', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
