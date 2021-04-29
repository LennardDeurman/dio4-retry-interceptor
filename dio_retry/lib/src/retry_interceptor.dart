import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'options.dart';

/// An interceptor that will try to send failed request again
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final Logger logger;
  final RetryOptions options;

  RetryInterceptor({@required this.dio, this.logger, RetryOptions options})
      : options = options ?? const RetryOptions();


  @override
  Future onError(DioError err, ErrorInterceptorHandler handler) async {
    var extra = RetryOptions.fromExtra(err.requestOptions) ?? options;

    var shouldRetry = extra.retries > 0 && await extra.retryEvaluator(err);
    if (shouldRetry) {
      if (extra.retryInterval.inMilliseconds > 0) {
        await Future.delayed(extra.retryInterval);
      }

      // Update options to decrease retry count before new try
      extra = extra.copyWith(retries: extra.retries - 1);
      err.requestOptions.extra = err.requestOptions.extra..addAll(extra.toExtra());

      try {
        logger?.warning(
            '[${err.requestOptions.uri}] An error occured during request, trying a again (remaining tries: ${extra.retries}, error: ${err.error})');
        // We retry with the updated options
        return dio.request(
          err.requestOptions.path,
          cancelToken: err.requestOptions.cancelToken,
          data: err.requestOptions.data,
          onReceiveProgress: err.requestOptions.onReceiveProgress,
          onSendProgress: err.requestOptions.onSendProgress,
          queryParameters: err.requestOptions.queryParameters,
          options: err.requestOptions ?? Options( //Why isn't RequestOptions a subtype of options?
            method: err.requestOptions.method,
            sendTimeout: err.requestOptions.sendTimeout,
            receiveTimeout: err.requestOptions.receiveTimeout,
            contentType: err.requestOptions.contentType,
            validateStatus: err.requestOptions.validateStatus,
            receiveDataWhenStatusError: err.requestOptions.receiveDataWhenStatusError,
            followRedirects: err.requestOptions.followRedirects,
            maxRedirects: err.requestOptions.maxRedirects,
            requestEncoder: err.requestOptions.requestEncoder,
            responseDecoder: err.requestOptions.responseDecoder,
            listFormat: err.requestOptions.listFormat,
          ),
        );
      } catch (e) {
        return e;
      }
    }

    return super.onError(err, handler);
  }

}
