.pragma library

/**
 * RetryUtils - Retry logic with exponential backoff
 * 
 * Provides robust retry mechanisms for network requests, process execution,
 * and other operations that may fail transiently.
 * 
 * Features:
 * - Exponential backoff
 * - Maximum retry attempts
 * - Jitter to prevent thundering herd
 * - Configurable delays
 */

/**
 * Retry configuration
 * 
 * @typedef {Object} RetryConfig
 * @property {number} maxAttempts - Maximum number of retry attempts (default: 3)
 * @property {number} initialDelay - Initial delay in milliseconds (default: 1000)
 * @property {number} maxDelay - Maximum delay in milliseconds (default: 30000)
 * @property {number} backoffMultiplier - Backoff multiplier (default: 2)
 * @property {boolean} enableJitter - Enable jitter to prevent thundering herd (default: true)
 * @property {function} shouldRetry - Function to determine if error should be retried (default: always retry)
 */

/**
 * Execute a function with retry logic
 * 
 * @param {function} fn - Function to execute (should return a promise or be async)
 * @param {RetryConfig} config - Retry configuration
 * @returns {Promise} - Promise that resolves with function result or rejects after all retries
 */
function retryWithBackoff(fn, config) {
    const {
        maxAttempts = 3,
        initialDelay = 1000,
        maxDelay = 30000,
        backoffMultiplier = 2,
        enableJitter = true,
        shouldRetry = () => true
    } = config || {}

    let attempt = 0
    let currentDelay = initialDelay

    function execute() {
        attempt++

        try {
            const result = fn()
            
            if (result && typeof result.then === 'function') {
                return result.catch(error => {
                    if (attempt >= maxAttempts || !shouldRetry(error)) {
                        throw error
                    }

                    const delay = Math.min(currentDelay, maxDelay)
                    const jitter = enableJitter ? Math.random() * 0.3 * delay : 0
                    const totalDelay = delay + jitter

                    currentDelay *= backoffMultiplier

                    return new Promise((resolve, reject) => {
                        setTimeout(() => {
                            execute().then(resolve).catch(reject)
                        }, totalDelay)
                    })
                })
            } else {
                return Promise.resolve(result)
            }
        } catch (error) {
            if (attempt >= maxAttempts || !shouldRetry(error)) {
                return Promise.reject(error)
            }

            const delay = Math.min(currentDelay, maxDelay)
            const jitter = enableJitter ? Math.random() * 0.3 * delay : 0
            const totalDelay = delay + jitter

            currentDelay *= backoffMultiplier

            return new Promise((resolve, reject) => {
                setTimeout(() => {
                    execute().then(resolve).catch(reject)
                }, totalDelay)
            })
        }
    }

    return execute()
}

/**
 * Create a retry wrapper for QML Process operations
 * 
 * @param {function} processFactory - Function that creates and returns a Process object
 * @param {RetryConfig} config - Retry configuration
 * @returns {Promise} - Promise that resolves when process succeeds or rejects after all retries
 */
function retryProcess(processFactory, config) {
    return retryWithBackoff(() => {
        return new Promise((resolve, reject) => {
            const process = processFactory()
            
            if (!process) {
                reject(new Error("Process factory returned null"))
                return
            }

            let resolved = false

            const cleanup = () => {
                if (process.onExited) {
                    process.exited.disconnect(onExited)
                }
                if (process.stdout && process.stdout.onStreamFinished) {
                    process.stdout.streamFinished.disconnect(onStreamFinished)
                }
                if (process.stderr && process.stderr.onStreamFinished) {
                    process.stderr.streamFinished.disconnect(onStreamError)
                }
            }

            const onExited = (exitCode) => {
                if (resolved) return
                resolved = true
                cleanup()

                if (exitCode === 0) {
                    resolve(process)
                } else {
                    reject(new Error(`Process exited with code ${exitCode}`))
                }
            }

            const onStreamFinished = () => {
            }

            const onStreamError = () => {
            }

            if (process.exited) {
                process.exited.connect(onExited)
            }

            if (process.stdout && process.stdout.streamFinished) {
                process.stdout.streamFinished.connect(onStreamFinished)
            }

            if (process.stderr && process.stderr.streamFinished) {
                process.stderr.streamFinished.connect(onStreamError)
            }

            process.running = true

            setTimeout(() => {
                if (!resolved) {
                    resolved = true
                    cleanup()
                    if (process.running) {
                        process.running = false
                    }
                    reject(new Error("Process timeout"))
                }
            }, config?.timeout || 10000)
        })
    }, config)
}

/**
 * Determine if an error should be retried
 * 
 * @param {Error} error - Error object
 * @returns {boolean} - True if error should be retried
 */
function isRetryableError(error) {
    if (!error) return false

    const errorMessage = error.message || error.toString() || ""
    const lowerMessage = errorMessage.toLowerCase()

    const retryablePatterns = [
        "timeout",
        "network",
        "connection",
        "econnrefused",
        "econnreset",
        "etimedout",
        "temporary",
        "503",
        "502",
        "504"
    ]

    const nonRetryablePatterns = [
        "authentication",
        "unauthorized",
        "401",
        "403",
        "404",
        "invalid",
        "malformed",
        "syntax"
    ]

    if (nonRetryablePatterns.some(pattern => lowerMessage.includes(pattern))) {
        return false
    }

    if (retryablePatterns.some(pattern => lowerMessage.includes(pattern))) {
        return true
    }

    return true
}

/**
 * Create a retry configuration from environment variables
 * 
 * @param {string} prefix - Environment variable prefix (e.g., "WEATHER")
 * @returns {RetryConfig} - Retry configuration
 */
function createRetryConfigFromEnv(prefix) {
    return {
        maxAttempts: 3,
        initialDelay: 1000,
        maxDelay: 30000,
        backoffMultiplier: 2,
        enableJitter: true,
        shouldRetry: isRetryableError
    }
}


