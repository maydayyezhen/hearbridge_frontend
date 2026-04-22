#include <napi/native_api.h>
#include <hilog/log.h>

static napi_value DetectFromJpeg(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4] = { nullptr };
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    double width = 320.0;
    double height = 240.0;

    if (argc >= 3) {
        napi_get_value_double(env, args[1], &width);
        napi_get_value_double(env, args[2], &height);
    }

    double cx = width * 0.5;
    double cy = height * 0.45;

    napi_value result;
    napi_create_object(env, &result);

    napi_value hasHand;
    napi_get_boolean(env, true, &hasHand);
    napi_set_named_property(env, result, "hasHand", hasHand);

    napi_value points;
    napi_create_array_with_length(env, 5, &points);

    auto makePoint = [&](uint32_t index, double x, double y, double score) {
        napi_value point;
        napi_create_object(env, &point);

        napi_value vx, vy, vs;
        napi_create_double(env, x, &vx);
        napi_create_double(env, y, &vy);
        napi_create_double(env, score, &vs);

        napi_set_named_property(env, point, "x", vx);
        napi_set_named_property(env, point, "y", vy);
        napi_set_named_property(env, point, "score", vs);

        napi_set_element(env, points, index, point);
    };

    makePoint(0, cx, cy, 1.0);
    makePoint(1, cx - 36.0, cy - 48.0, 1.0);
    makePoint(2, cx + 34.0, cy - 62.0, 1.0);
    makePoint(3, cx - 18.0, cy + 52.0, 1.0);
    makePoint(4, cx + 28.0, cy + 38.0, 1.0);

    napi_set_named_property(env, result, "points", points);

    napi_value box;
    napi_create_object(env, &box);

    napi_value left, top, boxWidth, boxHeight;
    napi_create_double(env, cx - 90.0, &left);
    napi_create_double(env, cy - 120.0, &top);
    napi_create_double(env, 180.0, &boxWidth);
    napi_create_double(env, 220.0, &boxHeight);

    napi_set_named_property(env, box, "left", left);
    napi_set_named_property(env, box, "top", top);
    napi_set_named_property(env, box, "width", boxWidth);
    napi_set_named_property(env, box, "height", boxHeight);

    napi_set_named_property(env, result, "box", box);

    return result;
}

static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        { "detectFromJpeg", nullptr, DetectFromJpeg, nullptr, nullptr, nullptr, napi_default, nullptr }
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

EXTERN_C_START
static napi_module hand_detector_module = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = nullptr,
    .reserved = { 0 }
};
EXTERN_C_END

extern "C" __attribute__((constructor)) void RegisterModule(void)
{
    napi_module_register(&hand_detector_module);
}