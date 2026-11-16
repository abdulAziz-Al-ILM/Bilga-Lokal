class ExperienceTemplate {
  final String id;
  final bool experiment;
  final List<String> fields;
  const ExperienceTemplate(this.id, this.fields, {this.experiment = false});
}

const experienceTemplates = [
  ExperienceTemplate('daily', ['body', 'feelings', 'lesson', 'next']),
  ExperienceTemplate('weekly', ['body', 'lesson', 'next']),
  ExperienceTemplate('gratitude', ['body', 'feelings', 'next']),
  ExperienceTemplate('decision', [
    'hypothesis',
    'method',
    'evidence',
    'result',
    'conclusions',
  ], experiment: true),
  ExperienceTemplate('experiment', [
    'hypothesis',
    'method',
    'observations',
    'evidence',
    'result',
    'conclusions',
  ], experiment: true),
  ExperienceTemplate('skill', [
    'hypothesis',
    'method',
    'observations',
    'result',
    'next',
  ], experiment: true),
  ExperienceTemplate('mistake', ['body', 'lesson', 'next']),
  ExperienceTemplate('success', ['body', 'evidence', 'lesson', 'next']),
  ExperienceTemplate('conversation', ['body', 'feelings', 'lesson', 'next']),
  ExperienceTemplate('reading', ['body', 'lesson', 'conclusions', 'next']),
  ExperienceTemplate('wellbeing', [
    'hypothesis',
    'method',
    'observations',
    'result',
    'conclusions',
  ], experiment: true),
  ExperienceTemplate('project', [
    'body',
    'evidence',
    'result',
    'conclusions',
    'next',
  ]),
];
