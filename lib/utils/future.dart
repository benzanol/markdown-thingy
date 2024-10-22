import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class FutureWaiter<T> extends StatelessWidget {
  const FutureWaiter({
      super.key,
      required this.future,
      this.waiting,
      this.onSuccess,
      this.onFail,
      this.onFinish,
  });
  final Future<T> future;

  final Widget? waiting;
  final Widget Function(BuildContext context, T value)? onSuccess;
  final Widget Function(BuildContext context, dynamic error)? onFail;
  final Function(BuildContext context)? onFinish;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return waiting ?? const SpinKitChasingDots(color: Colors.black);
        } else if (snapshot.hasError) {
          onFinish?.call(context);
          return onFail?.call(context, snapshot.error!) ?? Container();
        } else {
          onFinish?.call(context);
          return onSuccess?.call(context, snapshot.data as T) ?? Container();
        }
      },
    );
  }
}
