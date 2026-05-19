class SurveyListItem {
  final String id;
  final int surveyNumber;
  final String category;
  final String? subcategory;
  final String title;
  final String? subtitle;
  final int pointsReward;
  final bool isCompleted;
  final bool isAvailable;

  SurveyListItem({
    required this.id,
    required this.surveyNumber,
    required this.category,
    this.subcategory,
    required this.title,
    this.subtitle,
    required this.pointsReward,
    required this.isCompleted,
    required this.isAvailable,
  });

  factory SurveyListItem.fromJson(Map<String, dynamic> json) => SurveyListItem(
        id: json['id'],
        surveyNumber: json['survey_number'],
        category: json['category'],
        subcategory: json['subcategory'],
        title: json['title'],
        subtitle: json['subtitle'],
        pointsReward: json['points_reward'],
        isCompleted: json['is_completed'] ?? false,
        isAvailable: json['is_available'] ?? true,
      );

  String get categoryIcon {
    switch (category.toLowerCase()) {
      case 'insurance':
        return '🛡️';
      case 'real estate':
        return '🏠';
      case 'credit cards & banking':
        return '💳';
      case 'investing & retirement':
        return '📈';
      case 'legal & consumer rights':
        return '⚖️';
      case 'health & wellness spending':
        return '❤️';
      case 'education & career':
        return '🎓';
      case 'money & lifestyle':
        return '💰';
      default:
        return '📋';
    }
  }
}

class SurveyDetail {
  final String id;
  final int surveyNumber;
  final String category;
  final String? subcategory;
  final String title;
  final String? subtitle;
  final int pointsReward;
  final List<SurveyQuestion> questions;

  SurveyDetail({
    required this.id,
    required this.surveyNumber,
    required this.category,
    this.subcategory,
    required this.title,
    this.subtitle,
    required this.pointsReward,
    required this.questions,
  });

  factory SurveyDetail.fromJson(Map<String, dynamic> json) => SurveyDetail(
        id: json['id'],
        surveyNumber: json['survey_number'],
        category: json['category'],
        subcategory: json['subcategory'],
        title: json['title'],
        subtitle: json['subtitle'],
        pointsReward: json['points_reward'],
        questions: (json['questions'] as List)
            .map((q) => SurveyQuestion.fromJson(q))
            .toList(),
      );
}

class SurveyQuestion {
  final String id;
  final int questionNumber;
  final String questionType;
  final String questionText;
  final List<QuestionOption> options;
  final String? afterAnswerReveal;

  SurveyQuestion({
    required this.id,
    required this.questionNumber,
    required this.questionType,
    required this.questionText,
    required this.options,
    this.afterAnswerReveal,
  });

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) => SurveyQuestion(
        id: json['id'],
        questionNumber: json['question_number'],
        questionType: json['question_type'],
        questionText: json['question_text'],
        options: (json['options'] as List)
            .map((o) => QuestionOption.fromJson(o))
            .toList(),
        afterAnswerReveal: json['after_answer_reveal'],
      );
}

class QuestionOption {
  final String label;
  final String text;

  QuestionOption({required this.label, required this.text});

  factory QuestionOption.fromJson(Map<String, dynamic> json) => QuestionOption(
        label: json['label'],
        text: json['text'],
      );
}

class SurveyCompletionResult {
  final String completionId;
  final int baseReward;
  final double adMultiplier;
  final double premiumMultiplier;
  final int finalReward;
  final bool flagged;

  SurveyCompletionResult({
    required this.completionId,
    required this.baseReward,
    required this.adMultiplier,
    required this.premiumMultiplier,
    required this.finalReward,
    required this.flagged,
  });

  factory SurveyCompletionResult.fromJson(Map<String, dynamic> json) =>
      SurveyCompletionResult(
        completionId: json['completion_id'],
        baseReward: json['base_reward'],
        adMultiplier: (json['ad_multiplier'] as num).toDouble(),
        premiumMultiplier: (json['premium_multiplier'] as num).toDouble(),
        finalReward: json['final_reward'],
        flagged: json['flagged'] ?? false,
      );
}
