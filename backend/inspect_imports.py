
import importlib
import pkgutil
import inspect

packages_to_check = [
    "bedrock_agentcore",
    "boto3"
]

target_names = ["BedrockModel", "Agent", "calculator", "weather"]

def explore_package(package_name):
    try:
        module = importlib.import_module(package_name)
        print(f"\nScanning package: {package_name}")
        print(f"Top level dir: {dir(module)}")

        # Check direct attributes
        for name in target_names:
            if hasattr(module, name):
                print(f"FOUND: {name} in {package_name}")

        # Walk packages
        if hasattr(module, "__path__"):
            for _, name, _ in pkgutil.walk_packages(module.__path__, module.__name__ + "."):
                try:
                    sub_module = importlib.import_module(name)
                    # print(f"  Scanning submodule: {name}")
                    for target in target_names:
                        if hasattr(sub_module, target):
                            print(f"FOUND: {target} in {name}")
                except Exception as e:
                    # print(f"  Error scanning {name}: {e}")
                    pass

    except ImportError:
        print(f"Package not found: {package_name}")
    except Exception as e:
        print(f"Error scanning {package_name}: {e}")

for pkg in packages_to_check:
    explore_package(pkg)
