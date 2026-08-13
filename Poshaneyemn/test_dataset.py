import pandas as pd
import os

csv_path = r"C:\Users\rites\Downloads\anthrovision_labels.csv"

df = pd.read_csv(csv_path)

print("Rows:", len(df))

image_path = df["image_path_frontal1"].iloc[0]

print("\nFirst image path:")
print(image_path)

print("\nDoes file exist?")
print(os.path.exists(image_path))