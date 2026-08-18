from joblib import load

obj = load("cv_pipeline.joblib")

print("Feature names:")

try:
    print(obj.feature_names_in_)
except Exception as e:
    print(e)