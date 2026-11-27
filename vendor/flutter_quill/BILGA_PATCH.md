# Bilga privacy patch

Upstream: flutter_quill 11.6.0, published by the Flutter Quill project at https://pub.dev/packages/flutter_quill/versions/11.6.0 . MIT license retained. The published archive was verified against the SHA-256 supplied by the pub.dev version API before copying. Only lib/, pubspec, license and changelog are vendored.

One intentional source change: raw_editor_state_text_input_client_mixin.dart configures TextInputConfiguration with enableSuggestions=false, autocorrect=false and enableIMEPersonalizedLearning=false. Upstream 11.6.0 does not expose those controls on its editor configuration. This preserves Bilga’s existing private-input behavior. No microphone, network service or model is added.

Recheck this patch when upgrading; remove the fork once upstream exposes equivalent controls. App-level security regression tests inspect the actual TextInput.setClient configuration.
