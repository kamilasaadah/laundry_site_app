import 'package:flutter/material.dart';

// ──────────────────────────────────────────────
// DESIGN TOKENS
// ──────────────────────────────────────────────
class AppColors {
  static const primary       = Color(0xFF1A9E75);
  static const primaryLight  = Color(0xFFE8F4F0);
  static const primaryMid    = Color(0xFF0D6E56);
  static const accent        = Color(0xFFE84B6F);
  static const bgPage        = Color(0xFFF7FAF9);
  static const bgCard        = Color(0xFFFFFFFF);
  static const bgSearch      = Color(0xFFF2F6F5);
  static const textPrimary   = Color(0xFF0F1F1B);
  static const textSecondary = Color(0xFF7A9590);
  static const textMuted     = Color(0xFF9AADA6);
  static const border        = Color(0xFFEDF0EE);
  static const starColor     = Color(0xFFF5B93E);
  static const userDot       = Color(0xFF2979E8);
  static const routeLine     = Color(0xFF1565C0);
}

// ──────────────────────────────────────────────
// API CONFIGURATION
// ──────────────────────────────────────────────
const String gasUrl =
    "https://script.google.com/macros/s/AKfycbwZXYN5MFij2iQBvtluVy1VKarPskWPrvcg0RP5SD0MKj6-MqMMtVUvn-zdbgYACaxz/exec";

// ──────────────────────────────────────────────
// OSRM ROUTING API
// ──────────────────────────────────────────────
const String osrmUrl = 'https://router.project-osrm.org/route/v1/driving/';
