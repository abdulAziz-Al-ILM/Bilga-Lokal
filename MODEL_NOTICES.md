# Local inference sources

Models are downloaded only when the user chooses; model weights are not inside this patch or AAB.

- Voice interpretation uses ggml-org/Qwen3-0.6B-GGUF, revision afe8ad3577aa22500b3cd1c880f153b3b0e1cae8, Qwen3-0.6B-Q4_0.gguf, 428970080 bytes, SHA256 da2572f16c06133561ce56accaa822216f2391ef4d37fba427801cd6736417d4. The model is Apache-2.0. [Model card and license](https://huggingface.co/ggml-org/Qwen3-0.6B-GGUF).

- Qwen/Qwen3-4B-GGUF, revision bc640142c66e1fdd12af0bd68f40445458f3869b, Qwen3-4B-Q4_K_M.gguf, 2497280256 bytes, SHA256 7485fe6f11af29433bc51cab58009521f205840f5b4ae3a32fa7f92e8534fdf5.
- Qwen/Qwen3-8B-GGUF, revision 7c41481f57cb95916b40956ab2f0b139b296d974, Qwen3-8B-Q4_K_M.gguf, 5027783488 bytes, SHA256 d98cdcbd03e17ce47681435b5150e34c1417f50b5c0019dd560e4882c5745785.
- Official cards: https://huggingface.co/Qwen/Qwen3-4B-GGUF and https://huggingface.co/Qwen/Qwen3-8B-GGUF. Apache-2.0 model license. Preserve upstream attribution/license when redistributing weights.
- llama_flutter_android 0.2.6: https://pub.dev/packages/llama_flutter_android (MIT); vendored with license and embedded llama.cpp source/licenses. Bilga modifications: disable prompt/token logs; UTF-16/UTF-8 conversion and token-fragment buffering; context capacity rejection; wait for native generation before freeing memory; CPU baseline without mandatory dot-product/Vulkan inference; propagate asynchronous generation failures.
- Models can be inaccurate, omit information or produce unsuitable text. No financial transactions are executed by generated text.
