//  Licensing.m
//  Copyright (c) 2006-2010 Decimus Software, Inc. All rights reserved.


#import "Licensing.h"

#import "DSUtilities.h"

#pragma mark AP Carbon implementation

#include <openssl/rsa.h>
#include <openssl/sha.h>

static RSA *rsaKey;
static CFStringRef hash;
static CFMutableArrayRef blacklist;

static Boolean APSetKey(CFStringRef key)
{
    hash = CFSTR("");
    blacklist = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    
    // Create a new key
    rsaKey = RSA_new();
    
    // Public exponent is always 3
    BN_hex2bn(&rsaKey->e, "3");
    
    CFMutableStringRef mutableKey = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, key);
    if (!mutableKey)
        return FALSE;
    
    unsigned int maximumCStringLength = CFStringGetMaximumSizeForEncoding(CFStringGetLength(mutableKey), kCFStringEncodingMacRoman) + 1;
    char *keyCStringBuffer = malloc(maximumCStringLength);
    
    // Determine if we have a hex or decimal key
    CFStringLowercase(mutableKey, NULL);
    if (CFStringHasPrefix(mutableKey, CFSTR("0x"))) {
        CFStringTrim(mutableKey, CFSTR("0x"));
        CFStringGetCString(mutableKey, keyCStringBuffer, maximumCStringLength, kCFStringEncodingMacRoman);
        BN_hex2bn(&rsaKey->n, keyCStringBuffer);
    }
    else {
        CFStringGetCString(mutableKey, keyCStringBuffer, maximumCStringLength, kCFStringEncodingMacRoman);
        BN_dec2bn(&rsaKey->n, keyCStringBuffer);
    }
    CFRelease(mutableKey);
    free(keyCStringBuffer);
    
    return TRUE;
}

static CFStringRef APHash(void)
{
    return CFStringCreateCopy(kCFAllocatorDefault, hash);
}

static void APSetHash(CFStringRef newHash)
{
    if (hash != NULL)
        CFRelease(hash);
    hash = CFStringCreateCopy(kCFAllocatorDefault, newHash);
}

// Set the entire blacklist array, removing any existing entries
static void APSetBlacklist(CFArrayRef hashArray)
{
    if (blacklist != NULL)
        CFRelease(blacklist);
    blacklist = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, hashArray);
}

// Add a single entry to the blacklist-- provided because CFArray doesn't have an equivalent
// for NSArray's +arrayWithObjects, which means it may be easier to pass blacklist entries
// one at a time rather than building an array first and passing the whole thing.
static void APBlacklistAdd(CFStringRef blacklistEntry)
{
    CFArrayAppendValue(blacklist, blacklistEntry);
}

static CFDictionaryRef APCreateDictionaryForLicenseData(CFDataRef data)
{
    if (!rsaKey->n || !rsaKey->e)
        return NULL;
    
    // Make the property list from the data
    CFStringRef errorString = NULL;
    CFPropertyListRef propertyList;
    propertyList = CFPropertyListCreateFromXMLData(kCFAllocatorDefault, data, kCFPropertyListMutableContainers, &errorString);
    if (errorString || CFDictionaryGetTypeID() != CFGetTypeID(propertyList) || !CFPropertyListIsValid(propertyList, kCFPropertyListXMLFormat_v1_0)) {
        if (propertyList)
            CFRelease(propertyList);
        return NULL;
    }
    
    // Load the signature
    CFMutableDictionaryRef licenseDictionary = (CFMutableDictionaryRef)propertyList;
    if (!CFDictionaryContainsKey(licenseDictionary, CFSTR("Signature"))) {
        CFRelease(licenseDictionary);
        return NULL;
    }
    
    unsigned char sigBytes[128];
    CFDataRef sigData = CFDictionaryGetValue(licenseDictionary, CFSTR("Signature"));
	if(sigData)
		CFMakeCollectable(sigData);
    CFDataGetBytes(sigData, CFRangeMake(0, CFDataGetLength(sigData)), sigBytes);
    CFDictionaryRemoveValue(licenseDictionary, CFSTR("Signature"));
    
    // Decrypt the signature
    unsigned char checkDigest[128] = {0};
    if (RSA_public_decrypt(CFDataGetLength(sigData), sigBytes, checkDigest, rsaKey, RSA_PKCS1_PADDING) != SHA_DIGEST_LENGTH) {
        CFRelease(licenseDictionary);
        return NULL;
    }
    
    // Get the license hash
    CFMutableStringRef hashCheck = CFStringCreateMutable(kCFAllocatorDefault,0);
    int hashIndex;
    for (hashIndex = 0; hashIndex < SHA_DIGEST_LENGTH; hashIndex++)
        CFStringAppendFormat(hashCheck, NULL, CFSTR("%02x"), checkDigest[hashIndex]);
    APSetHash(hashCheck);
    CFRelease(hashCheck);
    
    if (blacklist && (CFArrayContainsValue(blacklist, CFRangeMake(0, CFArrayGetCount(blacklist)), hash) == true))
        return NULL;
    
    // Get the number of elements
    CFIndex count = CFDictionaryGetCount(licenseDictionary);
    // Load the keys and build up the key array
    CFMutableArrayRef keyArray = CFArrayCreateMutable(kCFAllocatorDefault, count, NULL);
    CFStringRef keys[count];
    CFDictionaryGetKeysAndValues(licenseDictionary, (const void**)&keys, NULL);
    int i;
    for (i = 0; i < count; i++)
        CFArrayAppendValue(keyArray, keys[i]);
    
    // Sort the array
    int context = kCFCompareCaseInsensitive;
    CFArraySortValues(keyArray, CFRangeMake(0, count), (CFComparatorFunction)CFStringCompare, &context);
    
    // Setup up the hash context
    SHA_CTX ctx;
    SHA1_Init(&ctx);
    // Convert into UTF8 strings
    for (i = 0; i < count; i++)
    {
        char *valueBytes;
        int valueLengthAsUTF8;
        CFStringRef key = CFArrayGetValueAtIndex(keyArray, i);
        CFStringRef value = CFDictionaryGetValue(licenseDictionary, key);
        
        // Account for the null terminator
        valueLengthAsUTF8 = CFStringGetMaximumSizeForEncoding(CFStringGetLength(value), kCFStringEncodingUTF8) + 1;
        valueBytes = (char *)malloc(valueLengthAsUTF8);
        CFStringGetCString(value, valueBytes, valueLengthAsUTF8, kCFStringEncodingUTF8);
        SHA1_Update(&ctx, valueBytes, strlen(valueBytes));
        free(valueBytes);
    }
    unsigned char digest[SHA_DIGEST_LENGTH];
    SHA1_Final(digest, &ctx);
    
    if (keyArray != NULL)
        CFRelease(keyArray);
    
    // Check if the signature is a match    
    for (i = 0; i < SHA_DIGEST_LENGTH; i++) {
        if (checkDigest[i] ^ digest[i]) {
            CFRelease(licenseDictionary);
            return NULL;
        }
    }
    
    // If it's a match, we return the dictionary; otherwise, we never reach this
    return licenseDictionary;
}

static CFDictionaryRef APCreateDictionaryForLicenseFile(CFURLRef path)
{
    // Read the XML file
    CFDataRef data;
    SInt32 errorCode;
    Boolean status;
    status = CFURLCreateDataAndPropertiesFromResource(kCFAllocatorDefault, path, &data, NULL, NULL, &errorCode);
    
    if (errorCode || status != true)
        return NULL;
    
    CFDictionaryRef licenseDictionary = APCreateDictionaryForLicenseData(data);
    CFRelease(data);
    return licenseDictionary;
}

static Boolean APVerifyLicenseData(CFDataRef data)
{
    CFDictionaryRef licenseDictionary = APCreateDictionaryForLicenseData(data);
    if (licenseDictionary) {
        CFRelease(licenseDictionary);
        return TRUE;
    } else {
        return FALSE;
    }
}

static Boolean APVerifyLicenseFile(CFURLRef path)
{
    CFDictionaryRef licenseDictionary = APCreateDictionaryForLicenseFile(path);
    if (licenseDictionary) {
        CFRelease(licenseDictionary);
        return TRUE;
    } else {
        return FALSE;
    }
}

#pragma mark Our registration code

NSString* DTLicenseDataKey = @"DTLicenseData";

unsigned char IS_REGISTERED {
	@try {
		NSData* licenseData = [[NSUserDefaults standardUserDefaults] objectForKey:DTLicenseDataKey];
		if(!licenseData)
			return PRODUCT_UNREGISTERED;
		
		// Generate a bogus but similar license to test the AP implementation with
		NSMutableDictionary* licenseDict = [NSPropertyListSerialization propertyListFromData:licenseData
																			mutabilityOption:NSPropertyListMutableContainers
																					  format:NULL
																			errorDescription:NULL];
		if(!licenseDict)
			return PRODUCT_UNREGISTERED;
		[licenseDict setObject:[NSString stringWithFormat:@"foo %@", newUniqueID()]
						forKey:@"Name"];
		
		NSData* licenseData2 = [NSPropertyListSerialization dataFromPropertyList:licenseDict
																		  format:NSPropertyListBinaryFormat_v1_0
																errorDescription:NULL];
		
		// Give AP our key
		NSMutableString *key = [NSMutableString string];
		[key appendString:@"0xB39EFD57949E59EF012F167D12BA"];
		[key appendString:@"3F39461698094D5618C5B81AD2BC83"];
		[key appendString:@"07C7D2"];
		[key appendString:@"B"];
		[key appendString:@"B"];
		[key appendString:@"59ACC7990BAFBB7761EA2E"];
		[key appendString:@"F75C349FE"];
		[key appendString:@"C"];
		[key appendString:@"C"];
		[key appendString:@"2AA8853044F7C478397"];
		[key appendString:@"732"];
		[key appendString:@"0"];
		[key appendString:@"0"];
		[key appendString:@"B79EEDC876D37EF73CDBBCDF4"];
		[key appendString:@"2B8F"];
		[key appendString:@"5"];
		[key appendString:@"5"];
		[key appendString:@"393ADEC9FBC1FD8E5A452EDC"];
		[key appendString:@""];
		[key appendString:@"6"];
		[key appendString:@"6"];
		[key appendString:@"8B9368BB282D490A494CFAC7C02F"];
		[key appendString:@"05838B8962"];
		[key appendString:@"9"];
		[key appendString:@"9"];
		[key appendString:@"F5CD7D290AAED51FF1"];
		[key appendString:@"B6E551322CBAB22387"];
		APSetKey((CFStringRef)key);
		
		// Reject if AP implementation accepts the bogus license
		NSDictionary* response = NSMakeCollectable(APCreateDictionaryForLicenseData((CFDataRef)licenseData2));
		if(response)
			return PRODUCT_UNREGISTERED;
		
		// Otherwise, return the dictionary from the given license data
		response = NSMakeCollectable(APCreateDictionaryForLicenseData((CFDataRef)licenseData));
		if(response)
			return PRODUCT_DTERM;
		
		return PRODUCT_UNREGISTERED;
	}
	@catch (NSException* e) {
		NSLog(@"Caught exception: %@");
	}
	
	return PRODUCT_UNREGISTERED;
}