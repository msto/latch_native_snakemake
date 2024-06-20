from latch.types.metadata import SnakemakeMetadata, LatchAuthor, EnvironmentConfig
from latch.types.directory import LatchDir

from .parameters import generated_parameters, file_metadata

SnakemakeMetadata(
    output_dir=LatchDir("latch://23203.account/latch_native_snakemake/output"),
    display_name="Native Snakemake Proof-of-Concept",
    author=LatchAuthor(
        name="Matt Stone",
    ),
    env_config=EnvironmentConfig(
        use_conda=False,
        use_container=False,
    ),
    cores=4,
    # Add more parameters
    parameters=generated_parameters,
    file_metadata=file_metadata,

)
