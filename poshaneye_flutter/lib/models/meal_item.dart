import 'package:flutter/material.dart';

class MealTag {
  final String label;
  final IconData icon;
  final Color bgClass;
  final Color textClass;

  MealTag({
    required this.label,
    required this.icon,
    required this.bgClass,
    required this.textClass,
  });
}

class MealItem {
  final String id;
  final String mealType; // Breakfast, Lunch, Afternoon Snack, Dinner
  final String time;
  final String title;
  final IconData icon;
  final List<MealTag> tags;

  MealItem({
    required this.id,
    required this.mealType,
    required this.time,
    required this.title,
    required this.icon,
    required this.tags,
  });

  MealItem copyWith({
    String? id,
    String? mealType,
    String? time,
    String? title,
    IconData? icon,
    List<MealTag>? tags,
  }) {
    return MealItem(
      id: id ?? this.id,
      mealType: mealType ?? this.mealType,
      time: time ?? this.time,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      tags: tags ?? this.tags,
    );
  }
}
