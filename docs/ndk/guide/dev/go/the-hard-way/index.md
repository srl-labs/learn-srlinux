# Developing NDK applications with Go

Given that a helper package called [`srl-labs/bond`][bond-repo] exists that abstracts the low-level NDK API and assists in the development of the NDK applications, there are not a lot of reasons to not use it. But, not a lot of reasons doesn't mean none.

Maybe your app needs a very specific manual control over the NDK API and convenience abstractions provided by Bond are not required. In that case, you are welcome to use the [NDK Go bindings](https://github.com/nokia/srlinux-ndk-go) directly.

The project structure stays exactly the same, regardless of using Bond or not, what changes is the amount of code required to interact with the NDK services. Let's take the same [`greeter` app](../index.md#meet-the-greeter) and implement it using the NDK Go bindings directly. It is recommended to get through the Bond-based development workflow first, as we will skip the parts that stay the same for both approaches.

The greeter app written with the NDK Go bindings directly is available at the same [`srl-labs/ndk-greeter-go`][greeter-go-repo] under the v0.1.0 tag.

[bond-repo]: https://github.com/srl-labs/bond
[greeter-go-repo]: https://github.com/srl-labs/ndk-greeter-go/tree/v0.1.0
