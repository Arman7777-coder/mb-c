import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/survey.dart';
import 'user_provider.dart';

final surveysProvider = FutureProvider<List<SurveyListItem>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getSurveys();
  return data.map((s) => SurveyListItem.fromJson(s)).toList();
});

final surveyDetailProvider =
    FutureProvider.family<SurveyDetail, String>((ref, surveyId) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getSurveyDetail(surveyId);
  return SurveyDetail.fromJson(data);
});
