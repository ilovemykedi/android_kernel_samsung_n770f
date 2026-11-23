/* Tab A7 ColorOS 13 port: Android 13 libnativewindow lacks
 * ANativeWindow_readFromParcel (API 34). The facehal links it but does not
 * need it for the camera path; report "not supported" instead of failing to link. */
struct AParcel; struct ANativeWindow;
__attribute__((visibility("default")))
int ANativeWindow_readFromParcel(const struct AParcel *parcel, struct ANativeWindow **out)
{
	(void)parcel;
	if (out) *out = 0;
	return -38; /* -ENOSYS */
}
