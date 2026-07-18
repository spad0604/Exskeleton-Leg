import 'package:injectable/injectable.dart';
import 'package:flutter_starter/data/entities/auth_session.dart';
import 'package:flutter_starter/data/entities/request/login_params.dart';
import 'package:flutter_starter/data/entities/request/register_params.dart';
import 'package:flutter_starter/data/entities/account.dart';
import 'package:flutter_starter/data/entities/patient_home.dart';
import 'package:flutter_starter/data/sources/network/dio.dart';

@singleton
class NetworkDataSource {
  final NetworkDio _dio;

  NetworkDataSource(this._dio);

  Future<Account> login(LoginParams params) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/login',
      data: params.toJson(),
    );
    final session = AuthSession.fromJson(_data(response.data));
    await _dio.persistSession(session);
    return session.user;
  }

  Future<Account> register(RegisterParams params) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/register',
      data: params.toJson(),
    );
    final session = AuthSession.fromJson(_data(response.data));
    await _dio.persistSession(session);
    return session.user;
  }

  Future<Account> getCurrentAccount() async {
    final response = await _dio.get<Map<String, dynamic>>('me');
    return Account.fromJson(_data(response.data));
  }

  Future<PatientHome> getPatientHome(String patientId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'patients/$patientId/home',
    );
    return PatientHome.fromJson(_data(response.data));
  }

  Future<void> logout() async {
    final refreshToken = await _dio.getRefreshToken();
    try {
      if (refreshToken != null) {
        await _dio.post<Map<String, dynamic>>(
          'auth/logout',
          data: {'refresh_token': refreshToken},
        );
      }
    } finally {
      await _dio.clearSession();
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic>? envelope) {
    final data = envelope?['data'];
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid API envelope');
  }
}
