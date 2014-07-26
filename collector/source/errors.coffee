createError = require "create-error"
Errors = {
    PermissionDenied:createError("PermissionDenied")
    ,AuthorizationFailed:createError("AuthorizationFailed")
    ,NetworkError:createError("NetworkError")
    ,TimeoutError:createError("TimeoutError")
    ,InvalidPinCode:createError("InvalidPinCode")
    ,InvalidSource:createError("InvalidSource")
    ,NotExists:createError("NotExists")
}
module.exports = Errors;