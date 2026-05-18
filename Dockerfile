# ==========================================
# STAGE 1: The Build Environment (Gradle + JDK)
# ==========================================
# Start with the official Gradle image backed by an Alpine Linux layer
FROM gradle:8.6.0-jdk17-alpine AS builder

# Set the working directory for the compilation workspace
WORKDIR /build

# Copy the configuration files that define dependencies first.
COPY build.gradle settings.gradle ./

# Trigger a dependency download step. This forces Gradle to pull down all the
# internet dependencies (JARs) into the container's local cache without compiling code yet.
RUN gradle dependencies --no-daemon

# Copy the actual application source code into the container
COPY src ./src

# Compile the source code and build the production fat JAR file.
# --no-daemon prevents Gradle from leaving idle background processes running in the builder.
# -x test skips running unit tests to optimize the image compilation speed.
RUN gradle build -x test --no-daemon


# ==========================================
# STAGE 2: The Production Runtime (JRE)
# ==========================================
# Start fresh with a clean, minimal JRE image. The Gradle build tool is entirely discarded.
FROM eclipse-temurin:17-jre-alpine AS runtime

# Enforce a secure directory for application execution
WORKDIR /app

# Create a non-root, system user and group for runtime isolation
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy the compiled .jar file from the 'builder' stage into this fresh runtime layer.
# In Gradle, the compiled outputs are stored in the 'build/libs/' directory.
COPY --from=builder /build/build/libs/*-all.jar ./app.jar

# Drop root executive privileges down to our restricted user
USER appuser

# Document the application's runtime networking port
EXPOSE 8080

# Run the Java application using the 'exec' form for proper OS signal handling
CMD ["java", "-jar", "app.jar"]
