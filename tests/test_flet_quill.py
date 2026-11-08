import asyncio
import unittest
from unittest.mock import AsyncMock, patch

from flet_quill import FletQuill, FletQuillEditor


class DeltaApiTests(unittest.TestCase):
    def test_initial_delta_and_empty_content(self):
        ops = [{"insert": "Hello\n", "attributes": {"bold": True}}]
        for control_type in (FletQuill, FletQuillEditor):
            with self.subTest(control_type=control_type):
                self.assertIsNone(control_type().text_data)
                self.assertEqual(control_type(text_data=ops).text_data, ops)

    def test_file_path_is_not_an_editor_argument(self):
        for control_type in (FletQuill, FletQuillEditor):
            with self.subTest(control_type=control_type):
                with self.assertRaises(TypeError):
                    control_type(file_path="document.txt")

    def test_save_returns_delta_operations(self):
        for control_type in (FletQuill, FletQuillEditor):
            with self.subTest(control_type=control_type):
                control = control_type()
                with patch.object(
                    control, "_invoke_method",
                    new_callable=AsyncMock,
                    return_value='[{"insert": "Hello\\n"}]',
                ) as invoke:
                    self.assertEqual(
                        asyncio.run(control.save()), [{"insert": "Hello\n"}]
                    )
                    invoke.assert_awaited_once_with("get_delta")


if __name__ == "__main__":
    unittest.main()
