part of '../../../main.dart';

String tx(String english, String swahili) =>
    appLanguage.value == AppLanguage.sw ? swahili : english;
