// RUN: %clang_cc1 -triple arm64-apple-ios11 -std=c++11 -fobjc-arc  -fobjc-weak -fobjc-runtime-has-weak -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple arm64-apple-ios11 -std=c++11 -fobjc-arc  -fobjc-weak -fobjc-runtime-has-weak -fclang-abi-compat=4.0 -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple arm64-apple-ios11 -std=c++11 -fobjc-arc  -fobjc-weak -fobjc-runtime-has-weak -emit-llvm -o - -DTRIVIALABI %s | FileCheck %s
// RUN: %clang_cc1 -triple arm64-apple-ios11 -std=c++11 -fobjc-arc  -fobjc-weak -fobjc-runtime-has-weak -fclang-abi-compat=4.0 -emit-llvm -o - -DTRIVIALABI %s | FileCheck %s

// Check that structs consisting solely of __strong or __weak pointer fields are
// destructed in the callee function and structs consisting solely of __strong
// pointer fields are passed directly.

// CHECK: %[[STRUCT_STRONGWEAK:.*]] = type { i8*, i8* }
// CHECK: %[[STRUCT_STRONG:.*]] = type { i8* }
// CHECK: %[[STRUCT_S:.*]] = type { i8* }
// CHECK: %[[STRUCT_CONTAINSNONTRIVIAL:.*]] = type { %{{.*}}, i8* }

#ifdef TRIVIALABI
struct __attribute__((trivial_abi)) StrongWeak {
#else
struct StrongWeak {
#endif
  id fstrong;
  __weak id fweak;
};

#ifdef TRIVIALABI
struct __attribute__((trivial_abi)) Strong {
#else
struct Strong {
#endif
  id fstrong;
};

template<class T>
#ifdef TRIVIALABI
struct __attribute__((trivial_abi)) S {
#else
struct S {
#endif
  T a;
};

struct NonTrivial {
  NonTrivial();
  NonTrivial(const NonTrivial &);
  ~NonTrivial();
  int *a;
};

// This struct is not passed directly nor destructed in the callee because f0
// has type NonTrivial.
struct ContainsNonTrivial {
  NonTrivial f0;
  id f1;
};

// CHECK: define void @_Z19testParamStrongWeak10StrongWeak(%[[STRUCT_STRONGWEAK]]* %{{.*}})
// CHECK: call %struct.StrongWeak* @_ZN10StrongWeakD1Ev(
// CHECK-NEXT: ret void

void testParamStrongWeak(StrongWeak a) {
}

// CHECK: define void @_Z18testCallStrongWeakP10StrongWeak(%[[STRUCT_STRONGWEAK]]* %[[A:.*]])
// CHECK: %[[A_ADDR:.*]] = alloca %[[STRUCT_STRONGWEAK]]*, align 8
// CHECK: %[[AGG_TMP:.*]] = alloca %[[STRUCT_STRONGWEAK]], align 8
// CHECK: store %[[STRUCT_STRONGWEAK]]* %[[A]], %[[STRUCT_STRONGWEAK]]** %[[A_ADDR]], align 8
// CHECK: %[[V0:.*]] = load %[[STRUCT_STRONGWEAK]]*, %[[STRUCT_STRONGWEAK]]** %[[A_ADDR]], align 8
// CHECK: %[[CALL:.*]] = call %[[STRUCT_STRONGWEAK]]* @_ZN10StrongWeakC1ERKS_(%[[STRUCT_STRONGWEAK]]* %[[AGG_TMP]], %[[STRUCT_STRONGWEAK]]* dereferenceable(16) %[[V0]])
// CHECK: call void @_Z19testParamStrongWeak10StrongWeak(%[[STRUCT_STRONGWEAK]]* %[[AGG_TMP]])
// CHECK-NOT: call
// CHECK: ret void

void testCallStrongWeak(StrongWeak *a) {
  testParamStrongWeak(*a);
}

// CHECK: define void @_Z20testReturnStrongWeakP10StrongWeak(%[[STRUCT_STRONGWEAK:.*]]* noalias sret %[[AGG_RESULT:.*]], %[[STRUCT_STRONGWEAK]]* %[[A:.*]])
// CHECK: %[[A_ADDR:.*]] = alloca %[[STRUCT_STRONGWEAK]]*, align 8
// CHECK: store %[[STRUCT_STRONGWEAK]]* %[[A]], %[[STRUCT_STRONGWEAK]]** %[[A_ADDR]], align 8
// CHECK: %[[V0:.*]] = load %[[STRUCT_STRONGWEAK]]*, %[[STRUCT_STRONGWEAK]]** %[[A_ADDR]], align 8
// CHECK: %[[CALL:.*]] = call %[[STRUCT_STRONGWEAK]]* @_ZN10StrongWeakC1ERKS_(%[[STRUCT_STRONGWEAK]]* %[[AGG_RESULT]], %[[STRUCT_STRONGWEAK]]* dereferenceable(16) %[[V0]])
// CHECK: ret void

StrongWeak testReturnStrongWeak(StrongWeak *a) {
  return *a;
}

// CHECK: define void @_Z15testParamStrong6Strong(i64 %[[A_COERCE:.*]])
// CHECK: %[[A:.*]] = alloca %[[STRUCT_STRONG]], align 8
// CHECK: %[[COERCE_DIVE:.*]] = getelementptr inbounds %[[STRUCT_STRONG]], %[[STRUCT_STRONG]]* %[[A]], i32 0, i32 0
// CHECK: %[[COERCE_VAL_IP:.*]] = inttoptr i64 %[[A_COERCE]] to i8*
// CHECK: store i8* %[[COERCE_VAL_IP]], i8** %[[COERCE_DIVE]], align 8
// CHECK: %[[CALL:.*]] = call %[[STRUCT_STRONG]]* @_ZN6StrongD1Ev(%[[STRUCT_STRONG]]* %[[A]])
// CHECK: ret void

// CHECK: define linkonce_odr %[[STRUCT_STRONG]]* @_ZN6StrongD1Ev(

void testParamStrong(Strong a) {
}

// CHECK: define void @_Z14testCallStrongP6Strong(%[[STRUCT_STRONG]]* %[[A:.*]])
// CHECK: %[[A_ADDR:.*]] = alloca %[[STRUCT_STRONG]]*, align 8
// CHECK: %[[AGG_TMP:.*]] = alloca %[[STRUCT_STRONG]], align 8
// CHECK: store %[[STRUCT_STRONG]]* %[[A]], %[[STRUCT_STRONG]]** %[[A_ADDR]], align 8
// CHECK: %[[V0:.*]] = load %[[STRUCT_STRONG]]*, %[[STRUCT_STRONG]]** %[[A_ADDR]], align 8
// CHECK: %[[CALL:.*]] = call %[[STRUCT_STRONG]]* @_ZN6StrongC1ERKS_(%[[STRUCT_STRONG]]* %[[AGG_TMP]], %[[STRUCT_STRONG]]* dereferenceable(8) %[[V0]])
// CHECK: %[[COERCE_DIVE:.*]] = getelementptr inbounds %[[STRUCT_STRONG]], %[[STRUCT_STRONG]]* %[[AGG_TMP]], i32 0, i32 0
// CHECK: %[[V1:.*]] = load i8*, i8** %[[COERCE_DIVE]], align 8
// CHECK: %[[COERCE_VAL_PI:.*]] = ptrtoint i8* %[[V1]] to i64
// CHECK: call void @_Z15testParamStrong6Strong(i64 %[[COERCE_VAL_PI]])
// CHECK: ret void

void testCallStrong(Strong *a) {
  testParamStrong(*a);
}

// CHECK: define i64 @_Z16testReturnStrongP6Strong(%[[STRUCT_STRONG]]* %[[A:.*]])
// CHECK: %[[RETVAL:.*]] = alloca %[[STRUCT_STRONG]], align 8
// CHECK: %[[A_ADDR:.*]] = alloca %[[STRUCT_STRONG]]*, align 8
// CHECK: store %[[STRUCT_STRONG]]* %[[A]], %[[STRUCT_STRONG]]** %[[A_ADDR]], align 8
// CHECK: %[[V0:.*]] = load %[[STRUCT_STRONG]]*, %[[STRUCT_STRONG]]** %[[A_ADDR]], align 8
// CHECK: %[[CALL:.*]] = call %[[STRUCT_STRONG]]* @_ZN6StrongC1ERKS_(%[[STRUCT_STRONG]]* %[[RETVAL]], %[[STRUCT_STRONG]]* dereferenceable(8) %[[V0]])
// CHECK: %[[COERCE_DIVE:.*]] = getelementptr inbounds %[[STRUCT_STRONG]], %[[STRUCT_STRONG]]* %[[RETVAL]], i32 0, i32 0
// CHECK: %[[V1:.*]] = load i8*, i8** %[[COERCE_DIVE]], align 8
// CHECK: %[[COERCE_VAL_PI:.*]] = ptrtoint i8* %[[V1]] to i64
// CHECK: ret i64 %[[COERCE_VAL_PI]]

Strong testReturnStrong(Strong *a) {
  return *a;
}

// CHECK: define void @_Z21testParamWeakTemplate1SIU6__weakP11objc_objectE(%[[STRUCT_S]]* %{{.*}})
// CHECK: call %struct.S* @_ZN1SIU6__weakP11objc_objectED1Ev(
// CHECK-NEXT: ret void

void testParamWeakTemplate(S<__weak id> a) {
}

// CHECK: define void @_Z27testParamContainsNonTrivial18ContainsNonTrivial(%[[STRUCT_CONTAINSNONTRIVIAL]]* %{{.*}})
// CHECK-NOT: call
// CHECK: ret void

void testParamContainsNonTrivial(ContainsNonTrivial a) {
}

// CHECK: define void @_Z26testCallContainsNonTrivialP18ContainsNonTrivial(
// CHECK: call void @_Z27testParamContainsNonTrivial18ContainsNonTrivial(%[[STRUCT_CONTAINSNONTRIVIAL]]* %{{.*}})
// CHECK: call %struct.ContainsNonTrivial* @_ZN18ContainsNonTrivialD1Ev(%[[STRUCT_CONTAINSNONTRIVIAL]]* %{{.*}})

void testCallContainsNonTrivial(ContainsNonTrivial *a) {
  testParamContainsNonTrivial(*a);
}
