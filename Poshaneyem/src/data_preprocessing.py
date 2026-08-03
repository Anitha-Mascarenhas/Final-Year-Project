import os
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder


class DataPreprocessor:
    """
    Handles loading, cleaning and preparing the AnthroVision dataset.
    """

    def __init__(self):

        # Project root
        self.project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

        # Dataset paths
        self.dataset_path = os.path.join(
            self.project_root,
            "dataset",
            "ANTHROVISION"
        )

        self.csv_path = os.path.join(
            self.dataset_path,
            "anthrovision_labels.csv"
        )

        # Load dataset
        self.df = pd.read_csv(self.csv_path)

        print(f"Dataset Loaded Successfully")
        print(f"Total Samples : {len(self.df)}")

    def clean_dataset(self):

        # Remove unnamed columns
        self.df = self.df.loc[:, ~self.df.columns.str.contains("^Unnamed")]

        # Remove duplicate rows
        self.df = self.df.drop_duplicates()

        # Remove rows with missing labels
        self.df = self.df.dropna(subset=["multiclass_label"])

        self.df.reset_index(drop=True, inplace=True)

        print("Dataset Cleaned Successfully")

    def encode_labels(self):

        self.encoder = LabelEncoder()

        self.df["label"] = self.encoder.fit_transform(
            self.df["multiclass_label"]
        )

        print("\nClasses")

        for i, cls in enumerate(self.encoder.classes_):
            print(f"{i} -> {cls}")

    def train_test_split(self):

        train_df, test_df = train_test_split(
            self.df,
            test_size=0.2,
            random_state=42,
            stratify=self.df["label"]
        )

        print(f"\nTraining Samples : {len(train_df)}")
        print(f"Testing Samples  : {len(test_df)}")

        return train_df, test_df


if __name__ == "__main__":

    processor = DataPreprocessor()

    processor.clean_dataset()

    processor.encode_labels()

    train_df, test_df = processor.train_test_split()