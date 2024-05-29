mod data {
    mod metadata;
}
mod components {
    mod strealm;
    mod erc721 {
        mod extensions;
    }
}
mod contracts {
    mod strealm;
    mod metadata {
        mod metadata;
        mod utils;
    }
}

mod tests {
    mod unit {
        #[cfg(test)]
        mod test_strealm_component;
    }
    mod integration {
        #[cfg(test)]
        mod test_lordship;
    }
    mod mocks {
        mod account_mock;
        mod erc20_mock;
        mod strealm_mock;
    }
}
