# Creating the Bond agent

It doesn't matter if the application is written in Go, Python, or any other gRPC-enabled language. It doesn't matter if the application is feature-rich or a simple greeting service. Every NDK app should perform the same routine steps to become a functional piece of the SR Linux Network OS.

We covered these steps in the [NDK Operations](../../../operations.md) guide in a great detail. Now we need to put this knowledge to practice and make our greeter application to do all these steps. Since dealing with these low level RPCs presented by the NDK is not always fun, we created the [**`srl-labs/bond`**][bond-repo] package.

Bond package is a helper Go package that abstracts the low-level NDK API and assists in the development of the NDK applications. It is a wrapper around the NDK gRPC services with utility functions that were designed to provide a more pleasant development experience. It deals with all the routine steps an app should go through and exposes some helper functions that can make writing NDK apps a fun experience.

We initialize our bond agent in the [`main.go`][main-go] file by specifying options of the Bond agent and starting it.

```{.go .code-scroll-lg}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:main-init-bond-agent"
```

We pass the logger instance created earlier to make the Bond agent log its messages to the same destination as the application.

Next, we pass the application context so that Bond can use this context with the attached metadata as well as cancelling its operations when the app's context is cancelled.

And last option is the application's root path, that we set as a constant in the `greeter` package. The application root path is the gNMI path of the root object of the application. Since our application's `greeter` container is mounted directly to the root of the SR Linux schema, the root path simply points to `/greeter`.

Once all the Bond options are set, we can start the Bond agent by calling the [`Start`][bond-pkg-start-fn] function. Start function will deal with the following:

1. Connect to the NDK service socket
2. Create gRPC service clients for all NDK services
3. Register the application within the NDK
4. Create a gNMI client to allow users to use gNMI when fetching or setting the data outside of the application' domain
5. Implement the graceful exit handler for the application
6. Listen to the notifications from the NDK's Config service to pass them to the application

As you can see, there is a lot that bond does for your application, which otherwise would be on developer' shoulders. We won't dive into the Bond operations in this guide, we wanted the app developer to focus on the application logic, and that is what we are going to do next.

:octicons-arrow-right-24: [Greeter application](app.md)

[bond-repo]: https://github.com/srl-labs/bond
[main-go]: https://github.com/srl-labs/ndk-greeter-go/blob/main/main.go
[bond-pkg-start-fn]: https://pkg.go.dev/github.com/srl-labs/bond#Agent.Start
