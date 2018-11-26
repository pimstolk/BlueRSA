//
//  CryptorRSA.swift
//  CryptorRSA
//
//  Created by Bill Abt on 1/17/17.
//
//  Copyright © 2017 IBM. All rights reserved.
//
// 	Licensed under the Apache License, Version 2.0 (the "License");
// 	you may not use this file except in compliance with the License.
// 	You may obtain a copy of the License at
//
// 	http://www.apache.org/licenses/LICENSE-2.0
//
// 	Unless required by applicable law or agreed to in writing, software
// 	distributed under the License is distributed on an "AS IS" BASIS,
// 	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// 	See the License for the specific language governing permissions and
// 	limitations under the License.
//

import Foundation

#if os(Linux)
    import OpenSSL
#endif

// MARK: -

// MARK: -

///
/// RSA Encryption/Decryption, Signing/Verification
///
@available(macOS 10.12, iOS 10.0, *)
public class CryptorRSA {
	
	// MARK: Class Functions
	
	///
	/// Create a plaintext data container.
	///
	/// - Parameters:
	///		- data:				`Data` containing the key data.
	///
	/// - Returns:				Newly initialized `PlaintextData`.
	///
	public class func createPlaintext(with data: Data) -> PlaintextData {
		
		return PlaintextData(with: data)
	}
	
	///
	/// Creates a message from a plaintext string, with the specified encoding.
	///
	/// - Parameters:
	///   - string: 			String value of the plaintext message
	///   - encoding: 			Encoding to use to generate the clear data
	///
	/// - Returns:				Newly initialized `PlaintextData`.
	///
	public class func createPlaintext(with string: String, using encoding: String.Encoding) throws -> PlaintextData {
		
		return try PlaintextData(with: string, using: encoding)
	}
	
	///
	/// Create an encrypted data container.
	///
	/// - Parameters:
	///		- data:				`Data` containing the encrypted data.
	///
	/// - Returns:				Newly initialized `EncryptedData`.
	///
	public class func createEncrypted(with data: Data) -> EncryptedData {
		
		return EncryptedData(with: data)
	}
	
	///
	/// Creates a message with a encrypted base64-encoded string.
	///
	/// - Parameters:
	///		- base64String: 	Base64-encoded data of an encrypted message
	///
	/// - Returns:				Newly initialized `EncryptedData`.
	///
	public class func createEncrypted(with base64String: String) throws -> EncryptedData {
		
		return try EncryptedData(withBase64: base64String)
	}
	
	///
	/// Create an signed data container.
	///
	/// - Parameters:
	///		- data:				`Data` containing the signed data.
	///
	/// - Returns:				Newly initialized `SignedData`.
	///
	public class func createSigned(with data: Data) -> SignedData {
		
		return SignedData(with: data)
	}
	
	///
	/// RSA Data Object: Allows for RSA Encryption/Decryption, Signing/Verification and various utility functions.
	///
	public class RSAData {
		
		// MARK: Enums
		
		/// Denotes the type of data this represents.
		public enum DataType {
			
			/// Plaintext
			case plaintextType
			
			/// Encrypted
			case encryptedType
			
			/// Signed
			case signedType
		}
		
		// MARK: -- Properties
		
		/// Data of the message
		public let data: Data
		
		/// Represents the type of data contained.
		public internal(set) var type: DataType = .plaintextType
		
		/// Base64-encoded string of the message data
		public var base64String: String {
			
			return data.base64EncodedString()
		}

		// MARK: -- Initializers
		
		///
		/// Initialize a new RSAData object.
		///
		/// - Parameters:
		///		- data:				`Data` containing the data.
		///		- type:				Type of data contained.
		///
		/// - Returns:				Newly initialized `RSAData`.
		///
		internal init(with data: Data, type: DataType) {
			
			self.data = data
			self.type = type
		}
		
		///
		/// Creates a RSAData with a encrypted base64-encoded string.
		///
		/// - Parameters:
	 	///		- base64String: 	Base64-encoded data of an encrypted message
		///
		/// - Returns:				Newly initialized `RSAData`.
		///
		internal init(withBase64 base64String: String) throws {
			
			guard let data = Data(base64Encoded: base64String) else {
				
				throw Error(code: CryptorRSA.ERR_BASE64_PEM_DATA, reason: "Couldn't convert base 64 encoded string ")
			}
			
			self.data = data
			self.type = .encryptedType
		}
		
		///
		/// Creates a message from a plaintext string, with the specified encoding.
		///
		/// - Parameters:
		///   - string: 			String value of the plaintext message
		///   - encoding: 			Encoding to use to generate the clear data
		///
		/// - Returns:				Newly initialized `RSAData`.
		///
		internal init(with string: String, using encoding: String.Encoding) throws {
			
			guard let data = string.data(using: encoding) else {
				
				throw Error(code: CryptorRSA.ERR_STRING_ENCODING, reason: "Couldn't convert string to data using specified encoding")
			}
			
			self.data = data
			self.type = .plaintextType
		}
		
		
		// MARK: -- Functions
		
		// MARK: --- Encrypt/Decrypt
		
		///
		/// Encrypt the data.
		///
		/// - Parameters:
		///		- key:				The `PublicKey`
		///		- algorithm:		The algorithm to use (`Data.Algorithm`).
		///
		///	- Returns:				A new optional `EncryptedData` containing the encrypted data.
		///
		public func encrypted(with key: PublicKey, algorithm: Data.Algorithm) throws -> EncryptedData? {
			
			// Must be plaintext...
			guard self.type == .plaintextType else {
				
				throw Error(code: CryptorRSA.ERR_NOT_PLAINTEXT, reason: "Data is not plaintext")
			}
			
			// Key must be public...
			guard key.type == .publicType else {
				
				throw Error(code: CryptorRSA.ERR_KEY_NOT_PUBLIC, reason: "Supplied key is not public")
			}
			
			#if os(Linux)
                
                // Convert RSA key to EVP
                var evp_key = EVP_PKEY_new()
				var rc = EVP_PKEY_set1_RSA(evp_key, .make(optional: key.reference))
                guard rc == 1 else {
                    let source = "Couldn't create key reference from key data"
                    if let reason = CryptorRSA.getLastError(source: source) {
                        
                        throw Error(code: ERR_ADD_KEY, reason: reason)
                    }
                    throw Error(code: ERR_ADD_KEY, reason: source + ": No OpenSSL error reported.")
                }

                // TODO: hash type option is not being used right now.
                let ( _, enc, padding) = algorithm.alogrithmForEncryption

				#if swift(>=4.2)
					let rsaEncryptCtx = EVP_CIPHER_CTX_new_wrapper()
				#else
    	            let rsaEncryptCtx = UnsafeMutablePointer<EVP_CIPHER_CTX>.allocate(capacity: 1)
				#endif
                
                defer {
					#if swift(>=4.2)
						EVP_CIPHER_CTX_reset_wrapper(rsaEncryptCtx)
						EVP_CIPHER_CTX_free_wrapper(rsaEncryptCtx)
					#else
	                    EVP_CIPHER_CTX_cleanup(rsaEncryptCtx)
					#endif
                    EVP_PKEY_free(evp_key)
                }

                EVP_CIPHER_CTX_set_padding(rsaEncryptCtx, padding)

                // Initialize the AES encryption key array (of size 1)
                typealias UInt8Ptr = UnsafeMutablePointer<UInt8>?
                var ek: UInt8Ptr
                ek = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(EVP_PKEY_size(evp_key)))
                let ekPtr = UnsafeMutablePointer<UInt8Ptr>.allocate(capacity: MemoryLayout<UInt8Ptr>.size)
                ekPtr.pointee = ek
                
                // Assign size of the corresponding cipher's IV
				let IVLength = EVP_CIPHER_iv_length(.make(optional: enc))
                let iv = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(IVLength))
                
                let encrypted = UnsafeMutablePointer<UInt8>.allocate(capacity: self.data.count + Int(IVLength))
                var encKeyLength: Int32 = 0
                var processedLength: Int32 = 0
                var encLength: Int32 = 0
                
                // Initializes a cipher context ctx for encryption with cipher type using a random secret key and IV.
                // The secret key is encrypted using the public key (evp_key can be an array of public keys)
                // Here we are using just 1 public key
				var status = EVP_SealInit(rsaEncryptCtx, .make(optional: enc), ekPtr, &encKeyLength, iv, &evp_key, 1)
                print(status) 
                // SealInit should return the number of public keys that were input, here it is only 1
                guard status == 1 else {
                    let source = "Encryption failed"
                    if let reason = CryptorRSA.getLastError(source: source) {
                        
                        throw Error(code: ERR_ENCRYPTION_FAILED, reason: reason)
                    }
                    throw Error(code: ERR_ENCRYPTION_FAILED, reason: source + ": No OpenSSL error reported.")
                }
                
                // EVP_SealUpdate is a complex macros and therefore the compiler doesnt
                // convert it directly to swift. From /usr/local/opt/openssl/include/openssl/evp.h:
                _ = self.data.withUnsafeBytes({ (plaintext: UnsafePointer<UInt8>) -> Int32 in
                    return EVP_EncryptUpdate(rsaEncryptCtx, encrypted, &processedLength, plaintext, Int32(self.data.count))
                })
                encLength = processedLength
                print("encLength \(encLength)") 
                status = EVP_SealFinal(rsaEncryptCtx, encrypted.advanced(by: Int(encLength)), &processedLength)
		print("status \(status)")
                guard status == 1 else {
                    let source = "Encryption failed"
                    if let reason = CryptorRSA.getLastError(source: source) {
                        
                        throw Error(code: ERR_ENCRYPTION_FAILED, reason: reason)
                    }
                    throw Error(code: ERR_ENCRYPTION_FAILED, reason: source + ": No OpenSSL error reported.")
                }
                encLength += processedLength
                
		print("encLength \(Int(encLength))")
		print("encKeyLength \(Int(encKeyLength))")
		print("IVLength \(Int(IVLength))")
                let cipher = Data(bytes: encrypted, count: Int(encLength))
                let ekFinal = Data(bytes: ek!, count: Int(encKeyLength))
                let ivFinal = Data(bytes: iv, count: Int(IVLength))
                
                return EncryptedData(with: ekFinal + cipher + ivFinal)
                
			#else
				
				var response: Unmanaged<CFError>? = nil
				let eData = SecKeyCreateEncryptedData(key.reference, algorithm.alogrithmForEncryption, self.data as CFData, &response)
				if response != nil {
				
					guard let error = response?.takeRetainedValue() else {
					
						throw Error(code: CryptorRSA.ERR_ENCRYPTION_FAILED, reason: "Encryption failed. Unable to determine error.")
					}
				
					throw Error(code: CryptorRSA.ERR_ENCRYPTION_FAILED, reason: "Encryption failed with error: \(error)")
				}
			
				return EncryptedData(with: eData! as Data)

			#endif
		}
		
		///
		/// Decrypt the data.
		///
		/// - Parameters:
		///		- key:				The `PrivateKey`
		///		- algorithm:		The algorithm to use (`Data.Algorithm`).
		///
		///	- Returns:				A new optional `PlaintextData` containing the decrypted data.
		///
		public func decrypted(with key: PrivateKey, algorithm: Data.Algorithm) throws -> PlaintextData? {
			
			// Must be encrypted...
			guard self.type == .encryptedType else {
				
				throw Error(code: CryptorRSA.ERR_NOT_ENCRYPTED, reason: "Data is plaintext")
			}
			
			// Key must be private...
			guard key.type == .privateType else {
				
				throw Error(code: CryptorRSA.ERR_KEY_NOT_PUBLIC, reason: "Supplied key is not private")
			}
			
			#if os(Linux)
				
                // Convert RSA key to EVP
                var evp_key = EVP_PKEY_new()
				var status = EVP_PKEY_set1_RSA(evp_key, .make(optional: key.reference))
                guard status == 1 else {
                    let source = "Couldn't create key reference from key data"
                    if let reason = CryptorRSA.getLastError(source: source) {
                        
                        throw Error(code: ERR_ADD_KEY, reason: reason)
                    }
                    throw Error(code: ERR_ADD_KEY, reason: source + ": No OpenSSL error reported.")
                }
                
                // TODO: hash type option is not being used right now.
                let ( _, encType, padding) = algorithm.alogrithmForEncryption
                
                // Size of symmetric encryption
                let encKeyLength = Int(EVP_PKEY_size(evp_key))
		print("encKeyLength \(Int(EVP_PKEY_size(evp_key)))")

                // Size of the corresponding cipher's IV
				let encIVLength = Int(EVP_CIPHER_iv_length(.make(optional: encType)))
			
		print("encIVLength \(Int(EVP_CIPHER_iv_length(.make(optional: encType))))")
                // Size of encryptedKey
                let encryptedDataLength = Int(self.data.count) - encKeyLength - encIVLength
		print("encryptedDataLength \(Int(self.data.count) - encKeyLength - encIVLength)")

                // Extract encryptedKey, encryptedData, encryptedIV from data
                // self.data = encryptedKey + encryptedData + encryptedIV
                let encryptedKey = self.data.subdata(in: 0..<encKeyLength)
                let encryptedData = self.data.subdata(in: encKeyLength..<encKeyLength+encryptedDataLength)
                let encryptedIV = self.data.subdata(in: encKeyLength+encryptedDataLength..<self.data.count)
                
				#if swift(>=4.2)
					let rsaDecryptCtx = EVP_CIPHER_CTX_new_wrapper()
				#else
    	            let rsaDecryptCtx = UnsafeMutablePointer<EVP_CIPHER_CTX>.allocate(capacity: 1)
				#endif
			
                defer {
					#if swift(>=4.2)
						EVP_CIPHER_CTX_reset_wrapper(rsaDecryptCtx)
						EVP_CIPHER_CTX_free_wrapper(rsaDecryptCtx)
					#else
	                    EVP_CIPHER_CTX_cleanup(rsaDecryptCtx)
					#endif
                    EVP_PKEY_free(evp_key)
                }
			
                EVP_CIPHER_CTX_set_padding(rsaDecryptCtx, padding)

                // processedLen is the number of bytes that each EVP_DecryptUpdate/EVP_DecryptFinal decrypts.
                // The sum of processedLen is the total size of the decrypted message (decMsgLen)
                var processedLen: Int32 = 0
                var decMsgLen: Int32 = 0
                
                let decrypted = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(encryptedData.count + encryptedIV.count))
                
                // EVP_OpenInit returns 0 on error or the recovered secret key size if successful
                status = encryptedKey.withUnsafeBytes({ (ek: UnsafePointer<UInt8>) -> Int32 in
                    return encryptedIV.withUnsafeBytes({ (iv: UnsafePointer<UInt8>) -> Int32 in
                        return EVP_OpenInit(rsaDecryptCtx, .make(optional: encType), ek, Int32(encryptedKey.count), iv, evp_key)
                    })
                })
                guard status != EVP_CIPHER_key_length(.make(optional: encType)) else {
                    let source = "Decryption failed"
                    if let reason = CryptorRSA.getLastError(source: source) {
                        
                        throw Error(code: ERR_DECRYPTION_FAILED, reason: reason)
                    }
                    throw Error(code: ERR_DECRYPTION_FAILED, reason: source + ": No OpenSSL error reported.")
                }
                
                // EVP_OpenUpdate is a complex macros and therefore the compiler doesnt
                // convert it directly to Swift. From /usr/local/opt/openssl/include/openssl/evp.h:
                _ = encryptedData.withUnsafeBytes({ (enc: UnsafePointer<UInt8>) -> Int32 in
                    return EVP_DecryptUpdate(rsaDecryptCtx, decrypted, &processedLen, enc, Int32(encryptedData.count))
                })
                decMsgLen = processedLen
                
                status = EVP_OpenFinal(rsaDecryptCtx, decrypted.advanced(by: Int(decMsgLen)), &processedLen)
                guard status != 0 else {
                    let source = "Decryption failed"
                    if let reason = CryptorRSA.getLastError(source: source) {
                        
                        throw Error(code: ERR_DECRYPTION_FAILED, reason: reason)
                    }
                    throw Error(code: ERR_DECRYPTION_FAILED, reason: source + ": No OpenSSL error reported.")
                }
                decMsgLen += processedLen
                
                return PlaintextData(with: Data(bytes: decrypted, count: Int(decMsgLen)))
                
			#else
				
				var response: Unmanaged<CFError>? = nil
				let pData = SecKeyCreateDecryptedData(key.reference, algorithm.alogrithmForEncryption, self.data as CFData, &response)
				if response != nil {
				
					guard let error = response?.takeRetainedValue() else {
					
						throw Error(code: CryptorRSA.ERR_DECRYPTION_FAILED, reason: "Decryption failed. Unable to determine error.")
					}
				
					throw Error(code: CryptorRSA.ERR_DECRYPTION_FAILED, reason: "Decryption failed with error: \(error)")
				}
				
				return PlaintextData(with: pData! as Data)
				
			#endif
		}
		
		
		// MARK: --- Sign/Verification
		
		///
		/// Sign the data
		///
		/// - Parameters:
		///		- key:				The `PrivateKey`.
		///		- algorithm:		The algorithm to use (`Data.Algorithm`).
		///
		///	- Returns:				A new optional `SignedData` containing the digital signature.
		///
		public func signed(with key: PrivateKey, algorithm: Data.Algorithm) throws -> SignedData? {
			
			// Must be plaintext...
			guard self.type == .plaintextType else {
				
				throw Error(code: CryptorRSA.ERR_NOT_PLAINTEXT, reason: "Data is not plaintext")
			}
			
			// Key must be private...
			guard key.type == .privateType else {
				
				throw Error(code: CryptorRSA.ERR_KEY_NOT_PRIVATE, reason: "Supplied key is not private")
			}
			
			#if os(Linux)
			
				#if swift(>=4.2)
					let md_ctx = EVP_MD_CTX_new_wrapper()
				#else
    	            let md_ctx = EVP_MD_CTX_create()
				#endif

                defer {
					#if swift(>=4.2)
						EVP_MD_CTX_free_wrapper(md_ctx)
					#else
	                    EVP_MD_CTX_destroy(md_ctx)
					#endif
                }
                
                // convert RSA key to EVP
                let evp_key = EVP_PKEY_new()
				var rc = EVP_PKEY_set1_RSA(evp_key, .make(optional: key.reference))
                guard rc == 1 else {
                    let source = "Couldn't create key reference from key data"
                    if let reason = CryptorRSA.getLastError(source: source) {
                        
                        throw Error(code: ERR_ADD_KEY, reason: reason)
                    }
                    throw Error(code: ERR_ADD_KEY, reason: source + ": No OpenSSL error reported.")
                }
                
                let (md, padding) = algorithm.algorithmForSignature
                
                // Provide a pkey_ctx to EVP_DigestSignInit so that the EVP_PKEY_CTX of the signing operation
                // is written to it, to allow alternative signing options to be set
                var pkey_ctx = EVP_PKEY_CTX_new(evp_key, nil)
                
                EVP_DigestSignInit(md_ctx, &pkey_ctx, .make(optional: md), nil, evp_key)
                
                // Now that Init has initialized pkey_ctx, set the padding option
                EVP_PKEY_CTX_ctrl(pkey_ctx, EVP_PKEY_RSA, -1, EVP_PKEY_CTRL_RSA_PADDING, padding, nil)
                
                // Convert Data to UnsafeRawPointer!
                _ = self.data.withUnsafeBytes({ (message: UnsafePointer<UInt8>) -> Int32 in
                    return EVP_DigestUpdate(md_ctx, message, self.data.count)
                })
                
                // Determine the size of the actual signature
                var sig_len: Int = 0
                EVP_DigestSignFinal(md_ctx, nil, &sig_len)
                let sig = UnsafeMutablePointer<UInt8>.allocate(capacity: sig_len)
                
                rc = EVP_DigestSignFinal(md_ctx, sig, &sig_len)
                guard rc == 1, sig_len > 0 else {
                    let source = "Signing failed."
                    if let reason = CryptorRSA.getLastError(source: source) {
                        
                        throw Error(code: ERR_SIGNING_FAILED, reason: reason)
                    }
                    throw Error(code: ERR_SIGNING_FAILED, reason: source + ": No OpenSSL error reported.")
                }
                
                return SignedData(with: Data(bytes: sig, count: sig_len))

			#else
				
				var response: Unmanaged<CFError>? = nil
				let sData = SecKeyCreateSignature(key.reference, algorithm.algorithmForSignature, self.data as CFData, &response)
				if response != nil {
				
					guard let error = response?.takeRetainedValue() else {
					
						throw Error(code: CryptorRSA.ERR_SIGNING_FAILED, reason: "Signing failed. Unable to determine error.")
					}
				
					throw Error(code: CryptorRSA.ERR_SIGNING_FAILED, reason: "Signing failed with error: \(error)")
				}
				
				return SignedData(with: sData! as Data)
				
			#endif
		}
		
		///
		/// Verify the signature
		///
		/// - Parameters:
		///		- key:				The `PublicKey`.
		///		- signature:		The `SignedData` containing the signature to verify against.
		///		- algorithm:		The algorithm to use (`Data.Algorithm`).
		///
		///	- Returns:				True if verification is successful, false otherwise
		///
		public func verify(with key: PublicKey, signature: SignedData, algorithm: Data.Algorithm) throws -> Bool {
			
			// Must be plaintext...
			guard self.type == .plaintextType else {
				
				throw Error(code: CryptorRSA.ERR_NOT_PLAINTEXT, reason: "Data is not plaintext")
			}
			
			// Key must be public...
			guard key.type == .publicType else {
				
				throw Error(code: CryptorRSA.ERR_KEY_NOT_PRIVATE, reason: "Supplied key is not public")
			}
			// Signature must be signed data...
			guard signature.type == .signedType else {
				
				throw Error(code: CryptorRSA.ERR_NOT_SIGNED_DATA, reason: "Supplied signature is not of signed data type")
			}
			
			#if os(Linux)
				
				#if swift(>=4.2)
					let md_ctx = EVP_MD_CTX_new_wrapper()
				#else
    	            let md_ctx = EVP_MD_CTX_create()
				#endif

                defer {
					#if swift(>=4.2)
						EVP_MD_CTX_free_wrapper(md_ctx)
					#else
	                    EVP_MD_CTX_destroy(md_ctx)
					#endif
                }

                // convert RSA key to EVP
                let evp_key = EVP_PKEY_new()
                var rc = EVP_PKEY_set1_RSA(evp_key, .make(optional: key.reference))
                guard rc == 1 else {
                    let source = "Couldn't create key reference from key data"
                    if let reason = CryptorRSA.getLastError(source: source) {
                        
                        throw Error(code: ERR_ADD_KEY, reason: reason)
                    }
                    throw Error(code: ERR_ADD_KEY, reason: source + ": No OpenSSL error reported.")
                }

                let (md, padding) = algorithm.algorithmForSignature
                
                // Provide a pkey_ctx to EVP_DigestSignInit so that the EVP_PKEY_CTX of the signing operation
                // is written to it, to allow alternative signing options to be set
                var pkey_ctx = EVP_PKEY_CTX_new(evp_key, nil)

                EVP_DigestVerifyInit(md_ctx, &pkey_ctx, .make(optional: md), nil, evp_key)

                // Now that EVP_DigestVerifyInit has initialized pkey_ctx, set the padding option
                EVP_PKEY_CTX_ctrl(pkey_ctx, EVP_PKEY_RSA, -1, EVP_PKEY_CTRL_RSA_PADDING, padding, nil)

                rc = self.data.withUnsafeBytes({ (message: UnsafePointer<UInt8>) -> Int32 in
                    return EVP_DigestUpdate(md_ctx, message, self.data.count)
                })
                guard rc == 1 else {
                    let source = "Signature verification failed."
                    if let reason = CryptorRSA.getLastError(source: source) {
                        
                        throw Error(code: ERR_VERIFICATION_FAILED, reason: reason)
                    }
                    throw Error(code: ERR_VERIFICATION_FAILED, reason: source + ": No OpenSSL error reported.")
                }

                // Unlike other return values above, this return indicates if signature verifies or not
                rc = signature.data.withUnsafeBytes({ (sig: UnsafePointer<UInt8>) -> Int32 in
                    // Wrapper for OpenSSL EVP_DigestVerifyFinal function defined in
                    // IBM-Swift/OpenSSL/shim.h, to provide compatibility with OpenSSL
                    // 1.0.1 and 1.0.2 on Ubuntu 14.04 and 16.04, respectively.
                    return SSL_EVP_digestVerifyFinal_wrapper(md_ctx, sig, signature.data.count)
                })
                
                return (rc == 1) ? true : false
				
			#else
				
				var response: Unmanaged<CFError>? = nil
				let result = SecKeyVerifySignature(key.reference, algorithm.algorithmForSignature, self.data as CFData, signature.data as CFData, &response)
				if response != nil {
				
					guard let error = response?.takeRetainedValue() else {
					
						throw Error(code: CryptorRSA.ERR_VERIFICATION_FAILED, reason: "Signature verification failed. Unable to determine error.")
					}
				
					throw Error(code: CryptorRSA.ERR_VERIFICATION_FAILED, reason: "Signature verification failed with error: \(error)")
				}
			
				return result
			
			#endif
		}
		
		// MARK: --- Utility
		
		///
		/// Retrieve a digest of the data using the specified algorithm.
		///
		/// - Parameters:
		///		- algorithm:		Algoririthm to use.
 		///
		///	- Returns:				`Data` containing the digest.
		///
		public func digest(using algorithm: Data.Algorithm) throws -> Data {
			
			return try self.data.digest(using: algorithm)
		}
		
		///
		/// String representation of message in specified string encoding.
		///
		/// - Parameters:
	 	///		- encoding: 		Encoding to use during the string conversion
		///
		/// - Returns: 				String representation of the message
		///
		public func string(using encoding: String.Encoding) throws -> String {
			
			guard let str = String(data: data, encoding: encoding) else {
				
				throw Error(code: CryptorRSA.ERR_STRING_ENCODING, reason: "Couldn't convert data to string representation")
			}
			
			return str
		}
		
	}
	
	// MARK: -
	
	///
	/// Plaintext Data - Represents data not encrypted or signed.
	///
	public class PlaintextData: RSAData {
		
		// MARK: Initializers
		
		///
		/// Initialize a new PlaintextData object.
		///
		/// - Parameters:
		///		- data:				`Data` containing the data.
		///
		/// - Returns:				Newly initialized `PlaintextData`.
		///
		internal init(with data: Data) {

			super.init(with: data, type: .plaintextType)
		}
		
		///
		/// Creates a message from a plaintext string, with the specified encoding.
		///
		/// - Parameters:
		///   - string: 			String value of the plaintext message
		///   - encoding: 			Encoding to use to generate the clear data
		///
		/// - Returns:				Newly initialized `RSAData`.
		///
		internal override init(with string: String, using encoding: String.Encoding) throws {
		
			try super.init(with: string, using: encoding)
		}
	}
	
	// MARK: -
	
	///
	/// Encrypted Data - Represents data encrypted.
	///
	public class EncryptedData: RSAData {
		
		// MARK: Initializers
		
		///
		/// Initialize a new EncryptedData object.
		///
		/// - Parameters:
		///		- data:				`Data` containing the data.
		///
		/// - Returns:				Newly initialized EncryptedData`.
		///
		public init(with data: Data) {
			
			super.init(with: data, type: .encryptedType)
		}
		
		///
		/// Creates a RSAData with a encrypted base64-encoded string.
		///
		/// - Parameters:
		///		- base64String: 	Base64-encoded data of an encrypted message
		///
		/// - Returns:				Newly initialized `RSAData`.
		///
		public override init(withBase64 base64String: String) throws {
		
			try super.init(withBase64: base64String)
		}
	}
	
	// MARK: -
	
	///
	/// Signed Data - Represents data that is signed.
	///
	public class SignedData: RSAData {
		
		// MARK: -- Initializers
		
		///
		/// Initialize a new SignedData object.
		///
		/// - Parameters:
		///		- data:				`Data` containing the data.
		///
		/// - Returns:				Newly initialized `SignedData`.
		///
		public init(with data: Data) {
			
			super.init(with: data, type: .signedType)
		}
		
	}
	
}

