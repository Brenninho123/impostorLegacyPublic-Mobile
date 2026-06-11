package cpp;

#if android
@:buildXml('
<target id="haxe">
	<lib name="android" />
	<lib name="log" />
</target>
')
@:cppFileCode('
#include <android/log.h>
#include <android/native_activity.h>
#include <android/window.h>
#include <jni.h>
#include <unistd.h>
#include <sys/statvfs.h>

static JavaVM* _jvm = nullptr;

static JNIEnv* getJNIEnv()
{
	JNIEnv* env = nullptr;
	if (_jvm != nullptr)
		_jvm->AttachCurrentThread(&env, nullptr);
	return env;
}

static jobject getActivity()
{
	JNIEnv* env = getJNIEnv();
	if (env == nullptr) return nullptr;
	jclass activityThread = env->FindClass("android/app/ActivityThread");
	jmethodID currentThread = env->GetStaticMethodID(activityThread, "currentActivityThread", "()Landroid/app/ActivityThread;");
	jobject thread = env->CallStaticObjectMethod(activityThread, currentThread);
	jmethodID getActivity = env->GetMethodID(activityThread, "getActivity", "()Landroid/app/Activity;");
	return env->CallObjectMethod(thread, getActivity);
}
')

class Android
{
	public static function init():Void
	{
		untyped __cpp__('
			JavaVM* jvm = nullptr;
			JNIEnv* env = nullptr;
			ANativeActivity* activity = (ANativeActivity*)SDL_AndroidGetActivity();
			if (activity != nullptr)
			{
				jvm = activity->vm;
				_jvm = jvm;
				jvm->AttachCurrentThread(&env, nullptr);
			}
		');
	}

	public static function getApiLevel():Int
	{
		return untyped __cpp__('
			(int)android_get_device_api_level()
		');
	}

	public static function log(tag:String, message:String):Void
	{
		untyped __cpp__('
			__android_log_print(ANDROID_LOG_DEBUG, {0}->utf8_str(), {1}->utf8_str());
		', tag, message);
	}

	public static function logWarning(tag:String, message:String):Void
	{
		untyped __cpp__('
			__android_log_print(ANDROID_LOG_WARN, {0}->utf8_str(), {1}->utf8_str());
		', tag, message);
	}

	public static function logError(tag:String, message:String):Void
	{
		untyped __cpp__('
			__android_log_print(ANDROID_LOG_ERROR, {0}->utf8_str(), {1}->utf8_str());
		', tag, message);
	}

	public static function getExternalStoragePath():String
	{
		return untyped __cpp__('
			::String(SDL_AndroidGetExternalStoragePath())
		');
	}

	public static function getInternalStoragePath():String
	{
		return untyped __cpp__('
			::String(SDL_AndroidGetInternalStoragePath())
		');
	}

	public static function getAvailableExternalStorage():Int64
	{
		return untyped __cpp__('
			struct statvfs stat;
			if (statvfs(SDL_AndroidGetExternalStoragePath(), &stat) != 0) return (int64_t)0;
			(int64_t)(stat.f_bavail * stat.f_frsize)
		');
	}

	public static function getAvailableInternalStorage():Int64
	{
		return untyped __cpp__('
			struct statvfs stat;
			if (statvfs(SDL_AndroidGetInternalStoragePath(), &stat) != 0) return (int64_t)0;
			(int64_t)(stat.f_bavail * stat.f_frsize)
		');
	}

	public static function vibrate(milliseconds:Int):Void
	{
		untyped __cpp__('
			JNIEnv* env = getJNIEnv();
			if (env == nullptr) return;
			jobject activity = getActivity();
			if (activity == nullptr) return;
			jclass cls = env->GetObjectClass(activity);
			jmethodID getSystemService = env->GetMethodID(cls, "getSystemService", "(Ljava/lang/String;)Ljava/lang/Object;");
			jstring serviceName = env->NewStringUTF("vibrator");
			jobject vibrator = env->CallObjectMethod(activity, getSystemService, serviceName);
			env->DeleteLocalRef(serviceName);
			if (vibrator == nullptr) return;
			jclass vibratorClass = env->GetObjectClass(vibrator);
			jmethodID vibrate = env->GetMethodID(vibratorClass, "vibrate", "(J)V");
			env->CallVoidMethod(vibrator, vibrate, (jlong){0});
			env->DeleteLocalRef(vibrator);
		', milliseconds);
	}

	public static function isExternalStorageWritable():Bool
	{
		return untyped __cpp__('
			(SDL_AndroidGetExternalStorageState() & SDL_ANDROID_EXTERNAL_STORAGE_WRITE) != 0
		');
	}

	public static function isExternalStorageReadable():Bool
	{
		return untyped __cpp__('
			(SDL_AndroidGetExternalStorageState() & SDL_ANDROID_EXTERNAL_STORAGE_READ) != 0
		');
	}

	public static function getDeviceModel():String
	{
		return untyped __cpp__('
			JNIEnv* env = getJNIEnv();
			if (env == nullptr) return ::String("unknown");
			jclass buildClass = env->FindClass("android/os/Build");
			jfieldID modelField = env->GetStaticFieldID(buildClass, "MODEL", "Ljava/lang/String;");
			jstring model = (jstring)env->GetStaticObjectField(buildClass, modelField);
			const char* modelStr = env->GetStringUTFChars(model, nullptr);
			::String result(modelStr);
			env->ReleaseStringUTFChars(model, modelStr);
			result
		');
	}

	public static function getDeviceManufacturer():String
	{
		return untyped __cpp__('
			JNIEnv* env = getJNIEnv();
			if (env == nullptr) return ::String("unknown");
			jclass buildClass = env->FindClass("android/os/Build");
			jfieldID mfrField = env->GetStaticFieldID(buildClass, "MANUFACTURER", "Ljava/lang/String;");
			jstring mfr = (jstring)env->GetStaticObjectField(buildClass, mfrField);
			const char* mfrStr = env->GetStringUTFChars(mfr, nullptr);
			::String result(mfrStr);
			env->ReleaseStringUTFChars(mfr, mfrStr);
			result
		');
	}

	public static function showToast(message:String, long:Bool = false):Void
	{
		untyped __cpp__('
			JNIEnv* env = getJNIEnv();
			if (env == nullptr) return;
			jobject activity = getActivity();
			if (activity == nullptr) return;
			jclass toastClass = env->FindClass("android/widget/Toast");
			jmethodID makeText = env->GetStaticMethodID(toastClass, "makeText",
				"(Landroid/content/Context;Ljava/lang/CharSequence;I)Landroid/widget/Toast;");
			jstring msg = env->NewStringUTF({0}->utf8_str());
			jint duration = {1} ? 1 : 0;
			jobject toast = env->CallStaticObjectMethod(toastClass, makeText, activity, msg, duration);
			jmethodID show = env->GetMethodID(toastClass, "show", "()V");
			env->CallVoidMethod(toast, show);
			env->DeleteLocalRef(msg);
			env->DeleteLocalRef(toast);
		', message, long);
	}

	public static function keepScreenOn(enable:Bool):Void
	{
		untyped __cpp__('
			JNIEnv* env = getJNIEnv();
			if (env == nullptr) return;
			jobject activity = getActivity();
			if (activity == nullptr) return;
			jclass cls = env->GetObjectClass(activity);
			jmethodID getWindow = env->GetMethodID(cls, "getWindow", "()Landroid/view/Window;");
			jobject window = env->CallObjectMethod(activity, getWindow);
			jclass windowClass = env->GetObjectClass(window);
			jmethodID addFlags = env->GetMethodID(windowClass, "addFlags", "(I)V");
			jmethodID clearFlags = env->GetMethodID(windowClass, "clearFlags", "(I)V");
			if ({0})
				env->CallVoidMethod(window, addFlags, (jint)0x00000080);
			else
				env->CallVoidMethod(window, clearFlags, (jint)0x00000080);
			env->DeleteLocalRef(window);
		', enable);
	}
}
#end
