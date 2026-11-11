import 'package:intl/intl.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:flutter/material.dart';

class DateConverter {

  static String formatDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd hh:mm:ss a').format(dateTime);
  }

  static String dateToTimeOnly(DateTime dateTime) {
    return DateFormat(_timeFormatter()).format(dateTime);
  }

  static String dateToDateAndTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }

  static String dateToDateAndTimeAm(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd ${_timeFormatter()}').format(dateTime);
  }

  static String dateTimeStringToDateTime(String dateTime) {
    return DateFormat('dd MMM yyyy  ${_timeFormatter()}').format(DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateTime));
  }

  static String dateTimeStringToDateOnly(String dateTime) {
    return DateFormat('dd MMM yyyy').format(DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateTime));
  }

  static DateTime dateTimeStringToDate(String dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateTime);
  }

  static DateTime isoStringToLocalDate(String dateTime) {
    return DateTime.parse(dateTime).toLocal();
  }

  static String isoStringToLocalString(String dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(dateTime).toLocal());
  }

  static String isoStringToDateTimeString(String dateTime) {
    return DateFormat('dd MMM yyyy  ${_timeFormatter()}').format(isoStringToLocalDate(dateTime));
  }

  static String convertStringTimeToDateChatting(DateTime time) {
    return DateFormat('EEE \'at\' ${_timeFormatter()}').format(time.toLocal());
  }

  static String isoStringToLocalDateOnly(String dateTime) {
    return DateFormat('dd MMM yyyy').format(isoStringToLocalDate(dateTime));
  }

  static String stringToLocalDateOnly(String dateTime) {
    return DateFormat('dd MMM yyyy').format(DateTime.parse(dateTime));
  }

  static String localDateToIsoString(DateTime dateTime) {
    return DateFormat('yyyy-MM-ddTHH:mm:ss.SSS').format(dateTime);
  }

  static String convertTimeToTime(String time) {
    return DateFormat(_timeFormatter()).format(DateFormat('HH:mm').parse(time));
  }

  static String convertStringTimeToDate(DateTime time) {
    return DateFormat('EEE \'at\' ${_timeFormatter()}').format(time.toLocal());
  }

  static String dateTimeStringToMonthAndTime(String dateTime) {
    return DateFormat('dd MMM yyyy HH:mm').format(isoStringToLocalDate(dateTime));
  }


  static String _timeFormatter() {
    return 'hh:mm a';
  }

  static String localDateToIsoStringAMPMOrder(DateTime dateTime) {
    return DateFormat('dd MMM yyyy, h:mm a ').format(dateTime.toLocal());
  }


  static String localDateToIsoStringAMPM(DateTime dateTime) {
    return DateFormat('d MMM, yyyy').format(dateTime.toLocal());
  }

  static String reviewDate(DateTime dateTime) {
    return DateFormat('dd MMM, yyyy ${_timeFormatter()}').format(dateTime.toLocal());
  }

  static String localDateToIsoStringDate(DateTime dateTime) {
    return DateFormat('d MMM, yyyy').format(dateTime.toLocal());
  }
  static String localToIsoString(DateTime dateTime) {
    return DateFormat('d MMMM, yyyy ').format(dateTime.toLocal());
  }

  static int getMonthIndex(String date) {
    return isoStringToLocalDate(date).month;
  }
  static int getYear(String date) {
    return isoStringToLocalDate(date).year;
  }

  static DateTime isoUtcStringToLocalTimeOnly(String dateTime) {
    return DateTime.parse(dateTime).toLocal();
  }

  static String toLocalFormattedDateTime(String dateTime) {
    final localDateTime = DateTime.parse(dateTime).toLocal();
    return DateFormat('dd MMM, yyyy | h:mm a').format(localDateTime);
  }

  static String isoStringToLocalDateAndTime(String dateTime) {
    return DateFormat('dd-MMM-yyyy hh:mm a').format(isoStringToLocalDate(dateTime));
  }

  static String dateStringMonthYear(DateTime ? dateTime) {
    return DateFormat('d MMM,y').format(dateTime!);
  }

  /// Pass [context] to get the label in the active language; without it the
  /// English wording is used (kept so existing call sites still compile).
  static String convert24HourTimeTo12HourTimeWithDay(DateTime time, bool isToday, {BuildContext? context}) {
    final String label = context != null
        ? (getTranslated(isToday ? 'today_at' : 'yesterday_at', context) ?? '')
        : (isToday ? 'Today at' : 'Yesterday at');
    return '$label ${DateFormat(_timeFormatter()).format(time)}';
  }

  static String convert24HourTimeTo12HourTime(DateTime time) {
    return DateFormat(_timeFormatter()).format(time);
  }

  static String formatTimeDateShort(DateTime dateTime) {
    return DateFormat('hh:mm a dd MMM yy').format(dateTime);
  }

  static String formatDateWithCommaAnd24Hour(DateTime dateTime) {
    return DateFormat('dd MMM, yyyy, HH:mm').format(dateTime.toLocal());
  }




  static String customTime(DateTime dateTime, {BuildContext? context}) {
    DateTime now = DateTime.now();
    DateTime justNow = now.subtract(const Duration(minutes: 1));
    DateTime localDateTime = dateTime.toLocal();

    if (!localDateTime.difference(justNow).isNegative) {
      return context != null ? (getTranslated('just_now', context) ?? 'just now') : 'just now';
    }

    String roughTimeString = DateFormat('jm').format(dateTime);

    if (localDateTime.day == now.day && localDateTime.month == now.month && localDateTime.year == now.year) {
      return roughTimeString;
    }

    DateTime yesterday = now.subtract(const Duration(days: 1));

    if (localDateTime.day == yesterday.day && localDateTime.month == now.month && localDateTime.year == now.year) {
      return context != null ? (getTranslated('yesterday', context) ?? 'yesterday') : 'yesterday';
    }

    if (now.difference(localDateTime).inDays < 4) {

      String weekday = DateFormat('EEEE').format(dateTime.toLocal());

      return weekday;
    }

    return localDateToIsoStringAMPM(dateTime);
  }


  static int countDays(DateTime ? dateTime) {
    final startDate = dateTime!;
    final endDate = DateTime.now();
    final difference = endDate.difference(startDate).inDays;
    return difference;
  }

  static String durationDateTime(DateTime dateTime) => DateFormat('MM/dd/yyyy hh:mm:ss a').format(dateTime);
  static DateTime? convertDurationDateTimeFromString(String? dateTime) => DateFormat('MM/dd/yyyy hh:mm:ss a').tryParse(dateTime ?? '');
}