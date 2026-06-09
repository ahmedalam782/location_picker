import 'package:equatable/equatable.dart';

enum StatusState { initial, loading, success, failure, moreLoading }

class BaseState<T> extends Equatable {
  final StatusState state;
  final T? data;
  final Exception? exception;

  const BaseState({required this.state, this.data, this.exception});

  R when<R>({
    required R Function(T data) success,
    required R Function() loading,
    R Function()? moreLoading,
    required R Function() initial,
    required R Function() failure,
  }) {
    return switch (state) {
      StatusState.initial => initial(),
      StatusState.loading => loading(),
      StatusState.moreLoading =>
        moreLoading != null ? moreLoading() : loading(),
      StatusState.success => (data is T) ? success(data as T) : failure(),
      StatusState.failure => failure(),
    };
  }

  R maybeWhen<R>({
    required R Function() orElse,
    R Function(T data)? success,
    R Function()? loading,
    R Function()? moreLoading,
    R Function()? initial,
    R Function()? failure,
  }) {
    return switch (state) {
      StatusState.initial => initial != null ? initial() : orElse(),
      StatusState.loading => loading != null ? loading() : orElse(),
      StatusState.moreLoading =>
        moreLoading != null
            ? moreLoading()
            : (loading != null ? loading() : orElse()),
      StatusState.success =>
        (success != null && data is T) ? success(data as T) : orElse(),
      StatusState.failure => failure != null ? failure() : orElse(),
    };
  }

  BaseState<T> copyWith({StatusState? state, T? data, Exception? exception}) {
    return BaseState<T>(
      state: state ?? this.state,
      data: data ?? this.data,
      exception: exception ?? this.exception,
    );
  }

  @override
  List<Object?> get props => [state, data, exception];
}
